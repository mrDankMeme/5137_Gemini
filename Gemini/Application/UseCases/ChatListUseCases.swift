/// Загрузка списка переписок.
struct LoadChatsUseCase: Sendable {
    private let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [ChatSummary] {
        try await repository.loadChats()
    }
}

/// Загрузка сообщений выбранной переписки.
struct LoadMessagesUseCase: Sendable {
    private let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(chatID: ChatSummary.ID) async throws -> [ChatMessage] {
        try await repository.loadMessages(chatID: chatID)
    }
}

/// Переименование переписки.
struct RenameChatUseCase: Sendable {
    private let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    /// Пустое название не сохраняем: список чатов без имени нечитаем.
    func callAsFunction(chatID: ChatSummary.ID, to title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await repository.rename(chatID: chatID, to: trimmed)
    }
}

/// Удаление переписки.
struct DeleteChatUseCase: Sendable {
    private let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(chatID: ChatSummary.ID) async throws {
        try await repository.delete(chatID: chatID)
    }
}
