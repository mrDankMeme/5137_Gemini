import Foundation

/// Сообщение в переписке.
///
/// Модель намеренно не знает про сеть: экран собирается на ней и сейчас, на моках,
/// и позже, когда придёт backend. Меняться будет источник, а не эта структура.
/// `nonisolated` по той же причине, что и `AIModel`: сообщения собирают
/// репозитории и локальный архив — они акторы вне главного.
nonisolated struct ChatMessage: Identifiable, Equatable {
    enum Author: Equatable {
        case user
        case assistant
    }

    /// Чем закончилась генерация ответа.
    ///
    /// `Codable`, чтобы `GenerationArchive` могло сохранить сообщение
    /// медиа-генерации ещё до того, как она закончилась, — иначе переписка
    /// не появлялась в истории, пока задача не готова.
    enum Status: Equatable, Codable {
        /// Ответ печатается или ещё грузится.
        case inProgress
        /// Готовый ответ.
        case complete
        /// Генерация не удалась — показываем красный пузырь и кнопку повтора.
        case failed
    }

    let id: String
    let author: Author
    var text: String
    var attachments: [ChatAttachment] = []
    var status: Status = .complete
    /// Результат генерации фото или видео, если сообщение — именно генерация.
    var generation: LibraryItem?
    /// Источники, на которые опирался ответ. Непусто только у ответов
    /// с поиском в интернете.
    var sources: [MessageSource] = []
}

/// Вложение пользователя: фото или документ.
///
/// Вынесено из `ChatMessage` отдельным типом, чтобы вложенность не уходила
/// на три уровня — так его проще передавать в компоненты вложений.
nonisolated struct ChatAttachment: Identifiable, Equatable {
    enum Kind: Equatable {
        case image
        case document(name: String)
    }

    let id: String
    let kind: Kind
    /// Содержимое файла. Пока пикеры не подключены — `nil`; сетевой репозиторий
    /// без него отправить вложение не сможет.
    var payload: Data?
    /// MIME-тип. Нужен и для загрузки, и для проверки лимита размера.
    var mimeType: String?
    /// Файл ещё загружается. В макете такая плитка показывает индикатор
    /// вместо иконки.
    var isUploading = false
}
