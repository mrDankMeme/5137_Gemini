import Foundation

/// ⚠️ ВРЕМЕННО: переписка без backend.
///
/// Существует только чтобы экраны можно было собрать и проверить до появления API.
/// Когда придёт спецификация, вместо этого файла появится сетевой репозиторий
/// с тем же протоколом — ни экраны, ни use case'ы менять не придётся.
actor PlaceholderChatRepository: ChatRepositoryProtocol {
    private var chats: [ChatSummary]
    private var messages: [ChatSummary.ID: [ChatMessage]] = [:]

    init() {
        chats = (0 ..< 7).map { ChatSummary(id: "chat-\($0)", title: "Organizing My Work Tasks") }
    }

    func loadChats() async throws -> [ChatSummary] {
        chats
    }

    func loadMessages(chatID: ChatSummary.ID) async throws -> [ChatMessage] {
        messages[chatID] ?? []
    }

    func send(
        message: String,
        attachments: [ChatAttachment],
        chatID: ChatSummary.ID?,
        modelID _: AIModel.ID,
        mode: ChatMode
    ) async throws -> SentMessage {
        // Задержка имитирует сеть: без неё не видно ни лоадера, ни кнопки «стоп».
        try await Task.sleep(for: .seconds(1))

        // Новую переписку заводит сервер — заглушка повторяет это поведение,
        // иначе клиентский код «а что делать с новым чатом» остался бы непроверенным.
        let id = chatID ?? "chat-\(UUID().uuidString)"
        var createdTitle: String?
        if !chats.contains(where: { $0.id == id }) {
            let title = String(message.prefix(40))
            chats.insert(ChatSummary(id: id, title: title), at: 0)
            createdTitle = title
        }

        let reply = ChatMessage(
            id: UUID().uuidString,
            author: .assistant,
            text: Self.sampleReply,
            // Источники приходят только у ответа с поиском — так же будет
            // и у настоящего backend.
            sources: mode.searchesWeb ? Self.sampleSources : []
        )
        messages[id, default: []].append(contentsOf: [
            ChatMessage(id: UUID().uuidString, author: .user, text: message, attachments: attachments),
            reply
        ])

        return SentMessage(chatID: id, chatTitle: createdTitle, message: reply)
    }

    func rename(chatID: ChatSummary.ID, to title: String) async throws {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index] = ChatSummary(id: chatID, title: title)
    }

    func delete(chatID: ChatSummary.ID) async throws {
        chats.removeAll { $0.id == chatID }
        messages[chatID] = nil
    }

    /// ⚠️ ВРЕМЕННО: ссылки-примеры для проверки блока источников.
    nonisolated static let sampleSources: [MessageSource] = [
        MessageSource(id: "1", title: "Greek yogurt nutrition facts",
                      url: URL(string: "https://www.healthline.com/nutrition/greek-yogurt")!),
        MessageSource(id: "2", title: "Why protein keeps you full",
                      url: URL(string: "https://www.nih.gov/protein-satiety")!)
    ]

    /// Ответ из макета — по нему сверялась вёрстка markdown.
    ///
    /// `nonisolated`: по умолчанию в проекте статика изолирована `MainActor`,
    /// а читает её актор репозитория — в Swift 6 это уже ошибка, не предупреждение.
    nonisolated static let sampleReply = """
    A quick, healthy breakfast idea that is simple, balanced, and truly satisfying:

    A bowl of Greek yogurt, berries, nuts, and honey — a combination of protein, fiber, \
    and healthy fats that keeps energy levels stable.

    ---

    **🥣 What it looks like in practice**

    - Greek yogurt — 150–200 g, preferably unsweetened
    - Fresh berries — blueberries, raspberries, strawberries
    - Nuts or seeds — almonds, walnuts, chia, or pumpkin seeds
    - Honey or maple syrup — just a teaspoon for flavor
    - Optional: a spoonful of oats or granola for crunch

    ---

    **⭐ Why it works**

    - High protein → satisfying
    - Healthy fats → provide lasting energy
    """
}
