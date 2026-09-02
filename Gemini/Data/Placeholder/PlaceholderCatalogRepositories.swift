import Foundation

/// ⚠️ ВРЕМЕННО: каталог моделей из макета.
///
/// Настоящий список отдаст ручка каталога; названия и описания взяты из Figma,
/// чтобы экран выбора модели можно было сверить с дизайном.
struct PlaceholderModelCatalogRepository: ModelCatalogRepositoryProtocol {
    func loadModels() async throws -> [AIModel] {
        [
            AIModel(
                id: "gemini-2.5-flash",
                title: "Gemini 2.5 Flash",
                subtitle: "A quick option for everyday tasks",
                capability: .text
            ),
            AIModel(
                id: "gemini-2.5-pro",
                title: "Gemini 2.5 Pro",
                subtitle: "Advanced reasoning for complex coding, analysis, and large contexts",
                capability: .text
            ),
            AIModel(
                id: "gemini-deep-think",
                title: "Gemini Deep Think",
                subtitle: "Deeper reasoning for complex tasks",
                capability: .text
            ),
            AIModel(
                id: "imagen-3",
                title: "Imagen 3",
                subtitle: "High-quality images with precise details and text rendering",
                capability: .image
            ),
            AIModel(
                id: "veo",
                title: "Veo",
                subtitle: "Generative video creation and scene animation from text",
                capability: .video
            ),
        ]
    }
}

/// ⚠️ ВРЕМЕННО: библиотека генераций без backend.
///
/// Ручки для сохранённых генераций в reference-проекте нет — это один из вопросов,
/// вынесенных на решение тимлида.
actor PlaceholderLibraryRepository: LibraryRepositoryProtocol {
    private var items: [LibraryItem] = [
        LibraryItem(id: "1", kind: .image, url: nil),
        LibraryItem(id: "2", kind: .image, url: nil),
        LibraryItem(id: "3", kind: .image, url: nil),
        LibraryItem(id: "4", kind: .video, url: nil),
        LibraryItem(id: "5", kind: .video, url: nil),
        LibraryItem(id: "6", kind: .video, url: nil),
        LibraryItem(id: "7", kind: .image, url: nil),
        LibraryItem(id: "8", kind: .image, url: nil),
    ]

    func loadItems() async throws -> [LibraryItem] {
        items
    }

    func save(_ item: LibraryItem) async throws {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.insert(item, at: 0)
    }

    func delete(_ item: LibraryItem) async throws {
        items.removeAll { $0.id == item.id }
    }
}

/// ⚠️ ВРЕМЕННО: данные аккаунта из макета.
///
/// Настоящие придут по авторизации устройства; баланс токенов обязан быть
/// серверным — локальное значение доказательством оплаты не является.
struct PlaceholderAccountRepository: AccountRepositoryProtocol {
    func loadAccountID() async throws -> String {
        "10101010"
    }

    /// Новый пользователь без токенов — в шапке будет «Pro».
    func loadPolicy() async throws -> (balance: Decimal, isSubscribed: Bool) {
        (0, false)
    }
}
