import Foundation

/// Данные для превью SwiftUI.
///
/// Живут в слое представления: сущностям домена фикстуры не принадлежат,
/// а слой данных отвечает за реальные источники.
///
/// Без `#if DEBUG` намеренно — макросы `#Preview` компилируются и в Release,
/// и под условной компиляцией релизная сборка ломается.
enum PreviewData {
    static let models: [AIModel] = [
        AIModel(id: "gemini-2.5-flash", title: "Gemini 2.5 Flash",
                subtitle: "A quick option for everyday tasks", capability: .text),
        AIModel(id: "gemini-2.5-pro", title: "Gemini 2.5 Pro",
                subtitle: "Advanced reasoning for complex coding, analysis, and large contexts",
                capability: .text),
        AIModel(id: "gemini-deep-think", title: "Gemini Deep Think",
                subtitle: "Deeper reasoning for complex tasks", capability: .text),
        AIModel(id: "imagen-3", title: "Imagen 3",
                subtitle: "High-quality images with precise details and text rendering",
                capability: .image),
        AIModel(id: "veo", title: "Veo",
                subtitle: "Generative video creation and scene animation from text",
                capability: .video)
    ]

    static let chats: [ChatSummary] = (0 ..< 7).map {
        ChatSummary(id: "chat-\($0)", title: "Organizing My Work Tasks")
    }

    static let libraryItems: [LibraryItem] = [
        LibraryItem(id: "1", kind: .image, url: nil),
        LibraryItem(id: "2", kind: .image, url: nil),
        LibraryItem(id: "3", kind: .video, url: nil),
        LibraryItem(id: "4", kind: .video, url: nil),
        LibraryItem(id: "5", kind: .image, url: nil),
        LibraryItem(id: "6", kind: .image, url: nil)
    ]

    static let subscriptionPlans: [PaywallPlan] = [
        PaywallPlan(id: "annual", title: "Annually", subtitle: "$60 / year",
                    price: "$1.15 / week", badge: "Save 60%"),
        PaywallPlan(id: "weekly", title: "Weekly", subtitle: nil,
                    price: "$3.85 / week", badge: nil)
    ]

    /// Источники для проверки блока ссылок под ответом.
    static let sources: [MessageSource] = [
        MessageSource(id: "1", title: "Greek yogurt nutrition facts",
                      url: URL(string: "https://www.healthline.com/nutrition/greek-yogurt")!),
        MessageSource(id: "2", title: "Why protein keeps you full",
                      url: URL(string: "https://www.nih.gov/protein-satiety")!)
    ]

    static let tokenPackages: [PaywallPlan] = [
        PaywallPlan(id: "t1000", title: "1000", subtitle: "100 generations",
                    price: "80 $", badge: "Save 20%", showsSparkle: true),
        PaywallPlan(id: "t600", title: "600", subtitle: "60 generations",
                    price: "60 $", badge: nil, showsSparkle: true)
    ]

    /// Спецпредложение: суммы держим здесь, а не в файлах пейвола — правило
    /// платформы запрещает захардкоженные цены в его UI.
    static let offerDiscount = "50% OFF"
    static let offerPlanName = "Special for you"
    static let offerPlanPeriod = "1 week"
    static let offerPrice = "$1.92"
    static let offerCrossedPrice = "$3.85"

    static let conversation: [ChatMessage] = [
        ChatMessage(id: "1", author: .user, text: "Give me an idea for a healthy breakfast"),
        ChatMessage(id: "2", author: .assistant, text: PlaceholderChatRepository.sampleReply)
    ]
}
