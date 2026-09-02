import Foundation

/// Режим ответа: обычный или с поиском в интернете.
///
/// Устроено режимом, а не булевым флагом «искать в интернете», потому что backend
/// у нас будет алиасом того же сервиса, что у 232: там это `generationModes`
/// из `/v1/chat/v2/capabilities` — `general` / `research` / `reasoning`, и каждый
/// режим стоит разное количество кредитов. Флаг пришлось бы переделывать в режим
/// сразу же, как придёт спецификация.
///
/// `reasoning` здесь намеренно нет: продуктового решения по нему не было,
/// а показывать в интерфейсе режим, который никто не заказывал, незачем.
enum ChatMode: String, CaseIterable, Identifiable, Sendable {
    /// Обычный ответ по знаниям модели.
    case general
    /// Ответ с поиском в интернете и ссылками на источники.
    case research

    nonisolated var id: String { rawValue }

    /// Значение для backend. Совпадает с `rawValue`, но отделено намеренно:
    /// подпись в интерфейсе и значение в запросе живут по разным правилам.
    nonisolated var wireValue: String { rawValue }

    /// Ищет ли этот режим в интернете. По нему интерфейс решает, показывать ли
    /// подпись «ищу в интернете» и блок источников.
    ///
    /// `nonisolated`: свойство читает и репозиторий-актор в слое данных,
    /// а по умолчанию в проекте всё изолировано `MainActor`.
    nonisolated var searchesWeb: Bool { self == .research }
}

/// Ссылка, на которую опирался ответ.
///
/// Показывается только у ответов с поиском: у обычного ответа источников нет
/// и быть не может — модель отвечает по своим знаниям.
nonisolated struct MessageSource: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let url: URL

    /// Домен для подписи под ответом: в ленте важен не полный адрес, а откуда взято.
    var host: String {
        url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }
}
