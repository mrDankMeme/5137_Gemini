import Foundation

/// Подсказка на главном экране. Список и порядок взяты из макета.
///
/// Иконки в Figma нарисованы вектором, здесь подобраны ближайшие системные символы:
/// они масштабируются, поддерживают Dynamic Type и не требуют экспорта ассетов.
struct SuggestedAction: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    /// Что подставляется в поле ввода. Подсказка — это начало запроса, а не
    /// готовый запрос: по нажатию текст падает в композер, человек дописывает
    /// своё и отправляет сам. Отправлять сразу нельзя — «Create Image» уходило
    /// чат-модели, которая картинку не рисует, и в ответ приходил текст.
    let prompt: String
    /// Какая модель нужна этому шаблону. Картинку рисует модель изображений,
    /// ролик — модель видео; для остального модель не меняем, человек мог
    /// выбрать её сам.
    var capability: AIModel.Capability?

    static let all: [SuggestedAction] = [
        SuggestedAction(
            id: "brainstorm",
            title: String(localized: "Brainstorm ideas"),
            systemImage: "lightbulb",
            prompt: String(localized: "Brainstorm ideas about ")
        ),
        SuggestedAction(
            id: "image",
            title: String(localized: "Create Image"),
            systemImage: "photo",
            prompt: String(localized: "Create an image of "),
            capability: .image
        ),
        SuggestedAction(
            id: "video",
            title: String(localized: "Create Video"),
            systemImage: "movieclapper",
            prompt: String(localized: "Create a video of "),
            capability: .video
        ),
        SuggestedAction(
            id: "habits",
            title: String(localized: "Develop habits"),
            systemImage: "hourglass",
            prompt: String(localized: "Help me build a habit of ")
        ),
        SuggestedAction(
            id: "post",
            title: String(localized: "Create post"),
            systemImage: "laptopcomputer",
            prompt: String(localized: "Write a post about ")
        ),
        SuggestedAction(
            id: "rewrite",
            title: String(localized: "Rewrite Text"),
            systemImage: "pencil",
            prompt: String(localized: "Rewrite this text: ")
        ),
        SuggestedAction(
            id: "code",
            title: String(localized: "Write code"),
            systemImage: "chevron.left.forwardslash.chevron.right",
            prompt: String(localized: "Write code that ")
        ),
        SuggestedAction(
            id: "study",
            title: String(localized: "Study with AI"),
            systemImage: "square.on.square",
            prompt: String(localized: "Explain in simple terms: ")
        ),
        SuggestedAction(
            id: "review",
            title: String(localized: "Daily Review"),
            systemImage: "magnifyingglass",
            prompt: String(localized: "Review my day: ")
        ),
        SuggestedAction(
            id: "letter",
            title: String(localized: "Write letter"),
            systemImage: "envelope",
            prompt: String(localized: "Write a letter to ")
        )
    ]
}
