import Foundation

/// Переписка через backend `claude-ios-backend`.
///
/// Отправка одним вызовом `/v1/chat/v2/run`: сессию заводит сервер и возвращает
/// её идентификатор в том же ответе — поэтому `send` отдаёт `SentMessage`,
/// а не одно сообщение.
actor NetworkChatRepository: ChatRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    // MARK: Список и история

    func loadChats() async throws -> [ChatSummary] {
        let response: ChatListDTO = try await client.get("/v1/chats", query: [
            URLQueryItem(name: "limit", value: "50")
        ])
        return response.items.map {
            ChatSummary(id: $0.id, title: $0.title ?? "New Chat")
        }
    }

    func loadMessages(chatID: ChatSummary.ID) async throws -> [ChatMessage] {
        let response: ChatHistoryDTO = try await client.get("/v1/chats/\(chatID)")
        return response.steps.compactMap { step in
            let blocks = (step.payload?.content ?? []).compactMap(\.text)
            // Вложение сервер возвращает не файлом, а текстовой заглушкой вида
            // `[attachment: image/jpeg "file", 5374095B — отправлено …]`.
            // Показывать её как текст пользователя нельзя: в пузыре и так стоит
            // сам снимок, а это служебная строка.
            let isPlaceholder = { (line: String) in
                line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[attachment:")
            }
            let hadAttachment = blocks.contains(where: isPlaceholder)
            let text = blocks
                .filter { !isPlaceholder($0) }
                .joined(separator: "\n")

            // Ходы без текста — служебные (вызовы инструментов), в переписке им
            // не место. Кроме случая, когда весь ход и был вложением.
            guard !text.isEmpty || hadAttachment else { return nil }

            return ChatMessage(
                id: step.id,
                author: step.role == "user" ? .user : .assistant,
                text: text
            )
        }
    }

    // MARK: Отправка

    func send(
        message: String,
        attachments: [ChatAttachment],
        chatID: ChatSummary.ID?,
        modelID: AIModel.ID,
        mode: ChatMode
    ) async throws -> SentMessage {
        let request = ChatRunDTO(
            userId: try await client.userID(),
            // `mode` здесь — тарификация, а не режим ответа: `credits` против `byok`.
            // Режим ответа уходит отдельным полем `generationMode`.
            mode: "credits",
            message: message,
            generationMode: mode.wireValue,
            model: modelID.isEmpty ? nil : modelID,
            sessionId: chatID,
            attachments: Self.encode(attachments)
        )

        let response: ChatRunResultDTO = try await client.post("/v1/chat/v2/run", body: request)

        // Отказ приходит с HTTP 200 и машиночитаемой причиной — разбирать текст
        // сообщения не нужно. Сервер уже завёл `sessionId` даже для
        // заблокированного ответа — теряя его здесь, следующая попытка ушла бы
        // без chatID и завела ещё один разговор вместо повтора в этом же.
        if response.status == "blocked" {
            throw Self.error(for: response.blockReason, chatID: response.sessionId)
        }

        let generation = try await firstGeneration(in: response.mediaJobs, chatID: response.sessionId)

        return SentMessage(
            chatID: response.sessionId,
            chatTitle: nil,
            message: ChatMessage(
                id: response.stepId ?? UUID().uuidString,
                author: .assistant,
                text: response.assistantMessage ?? "",
                generation: generation
            )
        )
    }

    // MARK: Переименование и удаление

    func rename(chatID: ChatSummary.ID, to title: String) async throws {
        let _: ChatPatchResultDTO = try await client.patch(
            "/v1/chats/\(chatID)",
            body: ChatRenameDTO(title: title)
        )
    }

    func delete(chatID: ChatSummary.ID) async throws {
        try await client.delete("/v1/chats/\(chatID)")
    }

    // MARK: Служебное

    /// MIME-типы, которые принимает бэкенд. Всё прочее он отвергает, поэтому
    /// раскладываем по его же категориям — список сверен с 232.
    private nonisolated static let documentTypes: Set<String> = ["application/pdf"]
    private nonisolated static let textTypes: Set<String> = [
        "text/plain", "text/markdown", "text/csv", "application/json"
    ]
    private nonisolated static let imageTypes: Set<String> = [
        "image/jpeg", "image/png", "image/gif", "image/webp"
    ]

    private nonisolated static func encode(_ attachments: [ChatAttachment]) -> [AttachmentDTO]? {
        let encoded: [AttachmentDTO] = attachments.compactMap { attachment in
            guard let payload = attachment.payload else { return nil }

            let name: String? = switch attachment.kind {
            case .image: nil
            case let .document(name): name
            }
            let mime = (attachment.mimeType ?? "").lowercased()

            let type: String
            let mediaType: String
            if imageTypes.contains(mime) {
                type = "image"
                mediaType = mime
            } else if documentTypes.contains(mime) {
                type = "document"
                mediaType = mime
            } else if textTypes.contains(mime) {
                type = "text"
                mediaType = mime
            } else if AttachmentFormatSupport.isValidUTF8(payload) {
                // Код и разметка (`.swift`, `.yaml`, `.html`) под список MIME
                // не попадают, но содержимое — валидный текст. Раньше такой файл
                // молча исчезал: чип показывался, а до модели он не доезжал.
                type = "text"
                mediaType = "text/plain"
            } else {
                return nil
            }

            return AttachmentDTO(
                type: type,
                mediaType: mediaType,
                filename: name,
                data: payload.base64EncodedString()
            )
        }
        return encoded.isEmpty ? nil : encoded
    }

    /// Причины блокировки — из описания контракта. Всё, что не про деньги,
    /// сводится к общей ошибке генерации: экран всё равно покажет повтор.
    private nonisolated static func error(for reason: String?, chatID: ChatSummary.ID?) -> ChatError {
        switch reason {
        case "credits_empty":
            .outOfTokens(chatID: chatID)
        case "trial_used", "subscription_required", "subscription_expired":
            .dailyLimitReached(chatID: chatID)
        default:
            .generationFailed(chatID: chatID)
        }
    }

    /// Ждёт первую задачу генерации. Опрос, а не подписка: у backend нет ни push,
    /// ни сокета под это, а картинка не появляется мгновенно.
    private func firstGeneration(
        in jobs: [MediaJobRefDTO]?,
        chatID: ChatSummary.ID
    ) async throws -> LibraryItem? {
        guard let job = jobs?.first else { return nil }

        for _ in 0 ..< Self.pollAttempts {
            try await Task.sleep(for: Self.pollInterval)
            guard !Task.isCancelled else { return nil }

            let state: MediaJobStateDTO = try await client.get("/v1/media/jobs/\(job.jobId)")
            switch state.status {
            case "succeeded", "completed", "done":
                return LibraryItem(
                    id: job.jobId,
                    kind: job.kind == "video" ? .video : .image,
                    url: state.assets.first.flatMap { URL(string: $0.url) }
                )
            case "failed", "cancelled":
                // Текст ответа уже мог прийти вместе с этим же `sessionId` — но
                // раз генерация задачи упала, весь ответ считаем неудавшимся
                // и просим повторить; chatID тем не менее сохраняем.
                throw ChatError.generationFailed(chatID: chatID)
            default:
                continue
            }
        }
        // Кончилось терпение, а не генерация: задача осталась на сервере
        // и подтянется в библиотеку при следующей загрузке.
        return nil
    }

    /// Видео у самой дорогой модели считается минутами, поэтому потолок ожидания
    /// щедрый; при этом экран не заперт — отправку можно остановить.
    private nonisolated static let pollAttempts = 90
    private nonisolated static let pollInterval: Duration = .seconds(2)

}

// MARK: - Формы ответов backend

private nonisolated struct ChatListDTO: Decodable {
    let items: [ChatListItemDTO]
}

private nonisolated struct ChatListItemDTO: Decodable {
    let id: String
    let title: String?
}

private nonisolated struct ChatHistoryDTO: Decodable {
    let steps: [ChatStepDTO]
}

private nonisolated struct ChatStepDTO: Decodable {
    let id: String
    let role: String
    let payload: ChatPayloadDTO?
}

private nonisolated struct ChatPayloadDTO: Decodable {
    let content: [ChatBlockDTO]?
}

private nonisolated struct ChatBlockDTO: Decodable {
    let type: String?
    let text: String?
}

private nonisolated struct ChatRunDTO: Encodable {
    let userId: String
    let mode: String
    let message: String
    let generationMode: String
    let model: String?
    let sessionId: String?
    let attachments: [AttachmentDTO]?
}

/// Форма ровно та, что принимает бэкенд, — сверено с 232 (`ChatV2Service`):
/// `type`, `mediaType`, `filename`, `data`. Раньше мы слали `fileName`/`mimeType`
/// и вовсе без `type`, и сервер отвергал сообщение с вложением целиком.
private nonisolated struct AttachmentDTO: Encodable {
    let type: String
    let mediaType: String
    let filename: String?
    let data: String
}

private nonisolated struct ChatRunResultDTO: Decodable {
    let status: String
    let sessionId: String
    let stepId: String?
    let assistantMessage: String?
    let blockReason: String?
    let mediaJobs: [MediaJobRefDTO]?
}

private nonisolated struct MediaJobRefDTO: Decodable {
    let jobId: String
    let kind: String
}

private nonisolated struct MediaJobStateDTO: Decodable {
    let status: String
    let assets: [MediaAssetDTO]
}

private nonisolated struct MediaAssetDTO: Decodable {
    let url: String
}

private nonisolated struct ChatRenameDTO: Encodable {
    let title: String
}

private nonisolated struct ChatPatchResultDTO: Decodable {
    let id: String
}
