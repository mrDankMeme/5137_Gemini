import Foundation

/// Ошибка обращения к backend.
///
/// Отделяет «нет сети» от «сервер отказал»: платформа запрещает превращать
/// offline и timeout в отказ по доступу — иначе пользователь без связи видит
/// предложение оформить подписку, которая у него уже есть.
nonisolated enum APIError: Error, Equatable {
    /// Сеть недоступна или запрос не уложился в срок.
    case offline
    /// Токен не принят. Обрабатывается лестницей восстановления в `APIClient`.
    case unauthorized
    /// Сервер ответил ошибкой с машиночитаемым кодом.
    case server(status: Int, code: String?, requestID: String?)
    /// Ответ не разобрался — контракт разошёлся с ожиданиями клиента.
    case decoding

    /// Ошибки, при которых имеет смысл повторить запрос: временные сбои сети
    /// и стороны сервера. 4xx повторять бессмысленно — ответ не изменится.
    var isRetryable: Bool {
        switch self {
        case .offline:
            true
        case let .server(status, _, _):
            status >= 500 || status == 408 || status == 429
        case .unauthorized, .decoding:
            false
        }
    }

    /// Разбирает системную ошибку в свою: коды «нет сети» отделяются от серверных,
    /// иначе вина за обрыв связи ложится на сервер.
    static func from(_ error: Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        guard let urlError = error as? URLError else { return .decoding }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
             .internationalRoamingOff, .secureConnectionFailed:
            return .offline
        default:
            return .offline
        }
    }
}

/// Конверт ошибки этого backend: `{"error":{code,message,requestId}}`.
nonisolated struct APIErrorEnvelope: Decodable {
    let error: APIErrorPayload
}

nonisolated struct APIErrorPayload: Decodable {
    let code: String?
    let message: String?
    let requestId: String?
}
