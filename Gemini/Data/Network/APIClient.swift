import Foundation

/// Транспорт к backend: авторизация устройства, повтор запроса после обновления
/// токена и разбор конверта ошибки.
///
/// Актор, потому что состояние авторизации общее у всех репозиториев, а обращаются
/// они к нему параллельно.
///
/// **Обновление токена — single-flight.** Refresh-токен одноразовый: при обмене
/// сервер выдаёт новый и гасит прежний. Если на 401 побежать двумя запросами
/// сразу, второй придёт с уже погашенным токеном и убьёт свежую сессию.
///
/// **Разлогинить пользователя нельзя в принципе.** Лестница восстановления
/// `refresh → token → register` целиком привязана к идентификатору устройства,
/// а он лежит в Keychain и переживает переустановку.
actor APIClient {
    private struct Tokens {
        var access: String
        var refresh: String
        var userID: String
    }

    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainStore

    private var tokens: Tokens?
    private var renewal: Task<Tokens, Error>?

    private enum Key {
        static let refreshToken = "auth.refresh"
        static let userID = "auth.user"
    }

    init(baseURL: URL, service: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        keychain = KeychainStore(service: service)
    }

    /// Идентификатор пользователя. Нужен телу запроса чата: сервер требует,
    /// чтобы он совпадал с `sub` в токене.
    func userID() async throws -> String {
        try await authorized().userID
    }

    // MARK: Запросы

    func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try await send(path: path, method: "GET", query: query, body: Optional<Empty>.none)
    }

    @discardableResult
    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await send(path: path, method: "POST", query: [], body: body)
    }

    @discardableResult
    func patch<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        try await send(path: path, method: "PATCH", query: [], body: body)
    }

    func delete(_ path: String) async throws {
        let _: Empty? = try await sendOptional(path: path, method: "DELETE", query: [], body: Optional<Empty>.none)
    }

    // MARK: Внутреннее

    private struct Empty: Codable {}

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Body?
    ) async throws -> Response {
        guard let value: Response = try await sendOptional(path: path, method: method, query: query, body: body) else {
            throw APIError.decoding
        }
        return value
    }

    private func sendOptional<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Body?
    ) async throws -> Response? {
        var current = try await authorized()

        for attempt in 0 ... 1 {
            let request = try makeRequest(path: path, method: method, query: query, body: body, token: current.access)
            let (data, response) = try await perform(request)

            guard let http = response as? HTTPURLResponse else { throw APIError.decoding }

            if http.statusCode == 401, attempt == 0 {
                // Токен мог протухнуть между проверкой и отправкой — обновляем и повторяем
                // ровно один раз: второй 401 подряд означает, что дело не в сроке.
                current = try await renew(after: current)
                continue
            }

            guard (200 ..< 300).contains(http.statusCode) else {
                throw serverError(status: http.statusCode, data: data)
            }
            if data.isEmpty { return nil }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding
            }
        }
        throw APIError.unauthorized
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.from(error)
        }
    }

    private func serverError(status: Int, data: Data) -> APIError {
        let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
        return .server(status: status, code: envelope?.error.code, requestID: envelope?.error.requestId)
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: (some Encodable)?,
        token: String
    ) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.decoding }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    // MARK: Авторизация

    private func authorized() async throws -> Tokens {
        if let tokens { return tokens }
        if let renewal { return try await renewal.value }
        return try await renew(after: nil)
    }

    /// Обновляет сессию. Параллельные вызовы присоединяются к уже идущему обмену:
    /// иначе второй запрос предъявит уже погашенный одноразовый refresh.
    private func renew(after stale: Tokens?) async throws -> Tokens {
        if let renewal, stale == nil || tokens?.access != stale?.access {
            return try await renewal.value
        }

        let task = Task<Tokens, Error> { [baseURL, session, keychain] in
            try await Self.restoreSession(baseURL: baseURL, session: session, keychain: keychain)
        }
        renewal = task

        defer { renewal = nil }
        let fresh = try await task.value
        tokens = fresh
        return fresh
    }

    private nonisolated static func restoreSession(
        baseURL: URL,
        session: URLSession,
        keychain: KeychainStore
    ) async throws -> Tokens {
        // Идентификатор устройства — единственное, что связывает человека с его
        // аккаунтом, поэтому у него своё хранилище с запасным источником:
        // молчаливый отказ Keychain уже приводил к новому пользователю на
        // каждом запуске. Подробности — в `DeviceIdentityStore`.
        let deviceID = DeviceIdentityStore(keychain: keychain).identity()

        if let refresh = keychain.string(for: Key.refreshToken),
           let tokens = try? await exchange(
               path: "/v1/auth/refresh",
               body: ["refreshToken": refresh],
               baseURL: baseURL, session: session, keychain: keychain
           ) {
            return tokens
        }

        if let tokens = try? await exchange(
            path: "/v1/auth/token",
            body: ["deviceId": deviceID],
            baseURL: baseURL, session: session, keychain: keychain
        ) {
            return tokens
        }

        return try await exchange(
            path: "/v1/auth/register",
            body: ["deviceId": deviceID],
            baseURL: baseURL, session: session, keychain: keychain
        )
    }

    private nonisolated static func exchange(
        path: String,
        body: [String: String],
        baseURL: URL,
        session: URLSession,
        keychain: KeychainStore
    ) async throws -> Tokens {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw APIError.unauthorized
        }

        struct TokenResponse: Decodable {
            let userId: String
            let accessToken: String
            let refreshToken: String
        }

        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw APIError.decoding
        }

        keychain.set(decoded.refreshToken, for: Key.refreshToken)
        keychain.set(decoded.userId, for: Key.userID)
        return Tokens(access: decoded.accessToken, refresh: decoded.refreshToken, userID: decoded.userId)
    }

    private var decoder: JSONDecoder { JSONDecoder() }
    private var encoder: JSONEncoder { JSONEncoder() }
}
