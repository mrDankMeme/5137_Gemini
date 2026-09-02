import Foundation

/// Генерация изображения или видео по описанию.
///
/// Отдельный сценарий, а не ветка отправки сообщения: у генерации свой каталог
/// моделей, своя цена в кредитах и свой путь на сервере — задача, которую
/// опрашивают до готовности. Через переписку она не заводится вовсе.
struct GenerateMediaUseCase: Sendable {
    private let repository: any MediaGenerationRepositoryProtocol

    init(repository: any MediaGenerationRepositoryProtocol) {
        self.repository = repository
    }

    /// Описание обязательно: без него генерировать нечего, и это решение
    /// домена, а не экрана — как и у отправки сообщения.
    func callAsFunction(
        prompt: String,
        chatID: ChatSummary.ID?,
        model: AIModel,
        kind: LibraryItem.Kind,
        settings: GenerationSettings,
        referenceImages: [ChatAttachment] = []
    ) async throws -> SentMessage {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatError.emptyMessage }

        return try await repository.generate(
            prompt: trimmed,
            chatID: chatID,
            model: model,
            kind: kind,
            settings: settings,
            referenceImages: referenceImages
        )
    }
}
