import Foundation

/// Переписки из двух источников: серверные и локальные, с генерациями.
///
/// У генерации нет сессии чата — `/v1/media/*` заводит job, а не разговор, —
/// поэтому её переписка живёт на устройстве. Экрану про это знать незачем:
/// он спрашивает список и сообщения, а какой из источников ответил, решает
/// идентификатор.
///
/// Локальные идут первыми: генерация свежее всего, что успел вернуть сервер,
/// а порядок в списке — по времени.
actor ArchivedChatRepository: ChatRepositoryProtocol {
    private let network: any ChatRepositoryProtocol
    private let archive: GenerationArchive

    init(network: any ChatRepositoryProtocol, archive: GenerationArchive) {
        self.network = network
        self.archive = archive
    }

    func loadChats() async throws -> [ChatSummary] {
        let local = await archive.summaries()
        // Сеть могла отвалиться, а локальные переписки есть всегда: терять их
        // из-за чужой ошибки нельзя — они больше нигде не хранятся.
        let remote = (try? await network.loadChats()) ?? []
        return local + remote
    }

    func loadMessages(chatID: ChatSummary.ID) async throws -> [ChatMessage] {
        guard GenerationArchive.isArchived(chatID) else {
            return try await network.loadMessages(chatID: chatID)
        }
        return await archive.messages(chatID: chatID)
    }

    func send(
        message: String,
        attachments: [ChatAttachment],
        chatID: ChatSummary.ID?,
        modelID: AIModel.ID,
        mode: ChatMode
    ) async throws -> SentMessage {
        // Написать текстом в переписку с генерациями нельзя: сервер такой
        // сессии не знает и завёл бы вместо ответа новую. Отправляем как
        // новую — это то же, что видит пользователь: чат начинается заново.
        let target = chatID.flatMap { GenerationArchive.isArchived($0) ? nil : $0 }
        return try await network.send(
            message: message,
            attachments: attachments,
            chatID: target,
            modelID: modelID,
            mode: mode
        )
    }

    func rename(chatID: ChatSummary.ID, to title: String) async throws {
        guard GenerationArchive.isArchived(chatID) else {
            return try await network.rename(chatID: chatID, to: title)
        }
        await archive.rename(chatID: chatID, to: title)
    }

    func delete(chatID: ChatSummary.ID) async throws {
        guard GenerationArchive.isArchived(chatID) else {
            return try await network.delete(chatID: chatID)
        }
        await archive.delete(chatID: chatID)
    }
}
