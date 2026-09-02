import Foundation

/// Сохранённая генерация в библиотеке.
/// `nonisolated` по той же причине, что и `AIModel`: элемент собирают
/// репозитории вне главного актора.
nonisolated struct LibraryItem: Identifiable, Equatable, Hashable {
    enum Kind: Equatable {
        case image
        case video
    }

    let id: String
    let kind: Kind
    /// Адрес готового файла. Появится вместе с backend — сейчас всегда `nil`.
    let url: URL?
    /// Запрос, по которому сделана генерация, и модель. Их отдаёт задача
    /// на сервере — без них кнопка «Regenerate» повторять было бы нечем,
    /// и она стояла неактивной.
    var prompt: String?
    var modelID: String?
}
