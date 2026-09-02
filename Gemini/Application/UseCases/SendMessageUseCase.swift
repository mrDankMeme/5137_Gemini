import Foundation

/// Отправка сообщения в переписку.
struct SendMessageUseCase: Sendable {
    private let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    /// Пустое сообщение отправлять нельзя — это решение домена, а не экрана.
    /// Но сообщение с одним вложением и без текста пустым не является:
    /// раньше такая отправка не доходила до сети вовсе и падала в общую
    /// ошибку «Failed to generate the response», будто ответил сервер.
    func callAsFunction(
        message: String,
        attachments: [ChatAttachment] = [],
        chatID: ChatSummary.ID?,
        modelID: AIModel.ID,
        mode: ChatMode
    ) async throws -> SentMessage {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { throw ChatError.emptyMessage }

        return try await repository.send(
            message: trimmed,
            attachments: attachments,
            chatID: chatID,
            modelID: modelID,
            mode: mode
        )
    }
}
