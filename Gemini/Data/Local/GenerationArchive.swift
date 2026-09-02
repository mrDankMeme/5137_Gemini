import Foundation

/// Переписки с генерациями, которые хранятся на устройстве.
///
/// У задачи генерации нет сессии чата: `/v1/media/*` заводит job, а не разговор,
/// и в `/v1/chats` она не появляется никогда. Пока архива не было, картинка
/// исчезала из переписки при выходе с экрана — оставалась только в библиотеке,
/// а сам «чат» пропадал вместе с ней.
///
/// Хранится в `Application Support`, а не в `Caches`: это единственная копия
/// диалога, и потерять её при чистке кеша нельзя. Сами файлы генераций тут
/// не лежат — только ссылки, их отдаёт сервер.
actor GenerationArchive {
    /// Префикс идентификатора локальной переписки. По нему репозиторий
    /// отличает её от серверной и не ходит за ней в сеть.
    static let idPrefix = "local:"

    private let fileURL: URL
    private var chats: [ArchivedChat]?

    init(fileName: String = "generation-archive.json") {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = directory.appendingPathComponent(fileName)
    }

    static func makeChatID() -> String {
        idPrefix + UUID().uuidString
    }

    static func isArchived(_ chatID: String) -> Bool {
        chatID.hasPrefix(idPrefix)
    }

    // MARK: Чтение

    func summaries() -> [ChatSummary] {
        load().map { ChatSummary(id: $0.id, title: $0.title) }
    }

    func messages(chatID: String) -> [ChatMessage] {
        load().first { $0.id == chatID }?.messages.map(\.message) ?? []
    }

    // MARK: Запись

    /// Заводит переписку сразу, ещё до того, как задача на сервере закончилась:
    /// запрос уже виден, ответ — лоадер (`status == .inProgress`, как у обычного
    /// печатающегося сообщения). Без этого переписка попадала в архив только
    /// по `complete(_:)`, и до тех пор её не было ни в истории, ни в side menu —
    /// уйдя из чата на видео, которое генерится минутами, найти его было негде.
    func beginPending(chatID: String, title: String, prompt: String, placeholderID: String) {
        var chats = load()
        let request = ChatMessage(id: UUID().uuidString, author: .user, text: prompt)
        let placeholder = ChatMessage(id: placeholderID, author: .assistant, text: "", status: .inProgress)

        if let index = chats.firstIndex(where: { $0.id == chatID }) {
            chats[index].messages.append(ArchivedMessage(message: request))
            chats[index].messages.append(ArchivedMessage(message: placeholder))
        } else {
            chats.insert(
                ArchivedChat(
                    id: chatID,
                    title: title,
                    messages: [ArchivedMessage(message: request), ArchivedMessage(message: placeholder)]
                ),
                at: 0
            )
        }
        save(chats)
    }

    /// Меняет плейсхолдер на готовый результат — по месту, тем же идентификатором.
    func complete(chatID: String, placeholderID: String, result: ChatMessage) {
        var chats = load()
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == placeholderID })
        else {
            return
        }
        chats[chatIndex].messages[messageIndex] = ArchivedMessage(message: result)
        save(chats)
    }

    /// Плейсхолдер остаётся в переписке, но с ошибкой — тот же красный пузырь
    /// с кнопкой повтора, что и у неудавшегося текстового ответа, а не немое
    /// исчезновение попытки.
    func fail(chatID: String, placeholderID: String) {
        var chats = load()
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == placeholderID })
        else {
            return
        }
        chats[chatIndex].messages[messageIndex].status = .failed
        save(chats)
    }

    func rename(chatID: String, to title: String) {
        var chats = load()
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        chats[index].title = title
        save(chats)
    }

    func delete(chatID: String) {
        save(load().filter { $0.id != chatID })
    }

    // MARK: Файл

    private func load() -> [ArchivedChat] {
        if let chats {
            return chats
        }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([ArchivedChat].self, from: $0) } ?? []
        chats = loaded
        return loaded
    }

    private func save(_ chats: [ArchivedChat]) {
        self.chats = chats
        guard let data = try? JSONEncoder().encode(chats) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Формы хранения

/// Отдельные от домена формы: `ChatMessage` не обязан уметь сериализоваться
/// ради одного хранилища, а формат файла не должен ломаться от правки сущности.
private nonisolated struct ArchivedChat: Codable {
    let id: String
    var title: String
    var messages: [ArchivedMessage]
}

private nonisolated struct ArchivedMessage: Codable {
    let id: String
    let isUser: Bool
    var text: String
    /// `nil` в файлах, сохранённых до появления плейсхолдеров, — читаем как
    /// `.complete`: сообщения того формата были только готовыми.
    var status: ChatMessage.Status?
    let generationID: String?
    let generationIsVideo: Bool?
    let generationURL: URL?

    init(message: ChatMessage) {
        id = message.id
        isUser = message.author == .user
        text = message.text
        status = message.status
        generationID = message.generation?.id
        generationIsVideo = message.generation.map { $0.kind == .video }
        generationURL = message.generation?.url
    }

    var message: ChatMessage {
        ChatMessage(
            id: id,
            author: isUser ? .user : .assistant,
            text: text,
            status: status ?? .complete,
            generation: generationID.map {
                LibraryItem(
                    id: $0,
                    kind: generationIsVideo == true ? .video : .image,
                    url: generationURL
                )
            }
        )
    }
}
