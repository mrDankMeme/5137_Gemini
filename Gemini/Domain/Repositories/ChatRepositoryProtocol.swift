import Foundation

/// Доступ к перепискам и сообщениям.
///
/// Домен описывает только то, **что** приложению нужно, и ничего не знает о том,
/// откуда это придёт. Сейчас протокол реализует заглушка в слое данных,
/// позже — сетевой репозиторий; экраны при этом не меняются.
protocol ChatRepositoryProtocol: Sendable {
    /// Список переписок для меню и поиска.
    func loadChats() async throws -> [ChatSummary]

    /// Сообщения конкретной переписки.
    func loadMessages(chatID: ChatSummary.ID) async throws -> [ChatMessage]

    /// Отправляет сообщение и возвращает ответ ассистента целиком.
    ///
    /// `chatID: nil` — это новая переписка: её заводит сервер и возвращает
    /// идентификатор в `SentMessage`, иначе следующее сообщение снова заведёт новую.
    ///
    /// Потоковую выдачу добавим отдельным методом, когда станет известно,
    /// умеет ли её backend: домыслы про формат ответа здесь неуместны.
    func send(
        message: String,
        attachments: [ChatAttachment],
        chatID: ChatSummary.ID?,
        modelID: AIModel.ID,
        mode: ChatMode
    ) async throws -> SentMessage

    func rename(chatID: ChatSummary.ID, to title: String) async throws
    func delete(chatID: ChatSummary.ID) async throws
}
