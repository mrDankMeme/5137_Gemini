import Foundation

/// Каталог моделей: чат из `/v1/models`, генерация из `/v1/media/models`.
///
/// Каталогов **два**, и это не дублирование. В `/v1/models` медиа-модели
/// перечислены под своими fal-идентификаторами (`fal-ai/nano-banana-2`), но
/// генерацию по ним завести нельзя: `/v1/chat/v2/run` отвечает на такой
/// идентификатор `422 «model is not available on this instance»`. Настоящие
/// идентификаторы генерации — короткие (`nano-banana-2`) и живут в своём
/// каталоге вместе с ценой в кредитах.
///
/// Списки отдаются **как есть**, без переупорядочивания внутри: правило
/// платформы для продуктов действует и здесь — что backend прислал, то и
/// показываем, включая пустой список.
actor NetworkModelCatalogRepository: ModelCatalogRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func loadModels() async throws -> [AIModel] {
        let response: ModelsDTO = try await client.get("/v1/models")
        let chat = response.models
            .filter { Self.capability(for: $0.modality) == .text }
            .map { model in
                AIModel(
                    id: model.id,
                    title: model.displayName,
                    subtitle: Self.subtitle(for: model.modality, provider: model.provider),
                    capability: .text,
                    isDefault: model.isDefault
                )
            }

        // Каталог генерации — не «ещё одна ручка того же»: без него в списке
        // оказываются идентификаторы, которые сервер не принимает. Упал он —
        // остаёмся с чатом, это лучше, чем пустой экран.
        let media = (try? await loadMediaModels(provider: Self.mediaProvider(in: response.models))) ?? []
        return chat + media
    }

    private func loadMediaModels(provider: String?) async throws -> [AIModel] {
        let response: MediaModelsDTO = try await client.get("/v1/media/models")
        return response.models.map { model in
            AIModel(
                id: model.id,
                title: Self.shortTitle(model.title),
                subtitle: Self.subtitle(for: model.kind, provider: provider),
                capability: model.kind == "video" ? .video : .image,
                credits: Self.cheapestCredits(of: model),
                resolutions: Self.resolutions(of: model)
            )
        }
    }

    /// Провайдер у каталога генерации не указан, а в макете подпись — «вид ·
    /// провайдер». Сопоставить модели двух каталогов по именам нельзя: там
    /// `kling-v3`, здесь `kling-video-v3`. Зато если у всех медиа-моделей
    /// общего списка провайдер один, он и есть искомый — а если их несколько,
    /// честнее не писать никакого, чем выбрать наугад.
    private nonisolated static func mediaProvider(in models: [ModelDTO]) -> String? {
        let providers = Set(
            models
                .filter { capability(for: $0.modality) != .text }
                .map(\.provider)
        )
        return providers.count == 1 ? providers.first : nil
    }

    /// Цена самой дешёвой генерации, **которую можно заказать из приложения**.
    ///
    /// Базовая цена каталога совпадает со ступенью `1K` — самой дешёвой из тех,
    /// что предлагает шторка параметров. У некоторых моделей в каталоге есть
    /// ступень `0.5K` дешевле, но выбрать её в интерфейсе нельзя: считать по ней
    /// «сколько это генераций» значило бы обещать недостижимое.
    private nonisolated static func cheapestCredits(of model: MediaModelDTO) -> Int? {
        model.credits ?? (model.resolutionCredits ?? [:]).values.min()
    }

    /// Ступени качества модель называет сама: у изображений они перечислены
    /// ценами, у видео — множителями. Ни того ни другого нет — ступеней модель
    /// не принимает, и параметр надо опустить.
    private nonisolated static func resolutions(of model: MediaModelDTO) -> [String] {
        // Два разных словаря: у изображений ступени перечислены ценами,
        // у видео — множителями к цене. Типы у них разные, поэтому не одним
        // выражением.
        if let credits = model.resolutionCredits, !credits.isEmpty {
            return Array(credits.keys)
        }
        if let multipliers = model.resolutionMultipliers, !multipliers.isEmpty {
            return Array(multipliers.keys)
        }
        return []
    }

    /// В каталоге генерации к названию приписано пояснение в скобках —
    /// «Nano Banana Pro (Gemini 3 Pro Image)». В строке пикера оно переносится
    /// на две, а имя модели — это то, что до скобки.
    private nonisolated static func shortTitle(_ title: String) -> String {
        guard let bracket = title.firstIndex(of: "(") else { return title }
        let name = title[..<bracket].trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? title : name
    }

    private nonisolated static func capability(for modality: String) -> AIModel.Capability {
        switch modality {
        case "photo", "image": .image
        case "video": .video
        default: .text
        }
    }

    /// Подпись под названием. Backend её не присылает, а в макете она есть,
    /// поэтому собирается из того, что он даёт: назначение и провайдер.
    private nonisolated static func subtitle(for modality: String, provider: String?) -> String {
        guard let provider else {
            return switch modality {
            case "photo", "image": String(localized: "Image generation")
            case "video": String(localized: "Video generation")
            default: String(localized: "Chat")
            }
        }
        return switch modality {
        case "photo", "image": String(localized: "Image generation · \(provider)")
        case "video": String(localized: "Video generation · \(provider)")
        default: String(localized: "Chat · \(provider)")
        }
    }
}

/// Аккаунт: идентификатор для поддержки и баланс кредитов.
actor NetworkAccountRepository: AccountRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func loadAccountID() async throws -> String {
        try await client.userID()
    }

    func loadPolicy() async throws -> (balance: Decimal, isSubscribed: Bool) {
        let response: PolicyDTO = try await client.get("/v1/policy/effective")
        return (Decimal(response.creditsBalance), response.isSubscribed)
    }
}

/// Библиотека генераций — задачи media, которые уже выполнил backend.
actor NetworkLibraryRepository: LibraryRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func loadItems() async throws -> [LibraryItem] {
        let response: MediaJobsDTO = try await client.get("/v1/media/jobs", query: [
            URLQueryItem(name: "limit", value: "50")
        ])

        return response.jobs
            // Незавершённые задачи в библиотеку не попадают: показывать нечего,
            // а серая плитка читается как сломанная генерация.
            .filter { !$0.assets.isEmpty }
            .map { job in
                LibraryItem(
                    id: job.jobId,
                    kind: job.kind == "video" ? .video : .image,
                    url: job.assets.first.flatMap { URL(string: $0.url) },
                    prompt: job.prompt,
                    modelID: job.model
                )
            }
    }

    /// Отдельной ручки «сохранить в библиотеку» у backend нет: генерация и так
    /// хранится на сервере с момента создания. Метод оставлен для совместимости
    /// с протоколом и ничего не делает.
    func save(_: LibraryItem) async throws {}

    func delete(_ item: LibraryItem) async throws {
        try await client.delete("/v1/media/jobs/\(item.id)")
    }
}

// MARK: - Формы ответов backend

private nonisolated struct ModelsDTO: Decodable {
    let models: [ModelDTO]
}

private nonisolated struct MediaModelsDTO: Decodable {
    let models: [MediaModelDTO]
}

private nonisolated struct MediaModelDTO: Decodable {
    let id: String
    let title: String
    /// `image` или `video`.
    let kind: String
    /// Базовая цена генерации в кредитах.
    let credits: Int?
    /// Цена по ступеням качества, если они у модели есть.
    let resolutionCredits: [String: Int]?
    /// У видео ступени заданы не ценой, а множителем к ней.
    let resolutionMultipliers: [String: Double]?
}

private nonisolated struct ModelDTO: Decodable {
    let id: String
    let displayName: String
    let modality: String
    let provider: String
    /// Семейство модели: у медиа совпадает с идентификатором в каталоге генерации.
    let family: String?
    /// В JSON поле называется `default` — это ключевое слово Swift.
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, displayName, modality, provider, family
        case isDefault = "default"
    }
}

private nonisolated struct PolicyDTO: Decodable {
    let creditsBalance: Int
    let isSubscribed: Bool
}

private nonisolated struct MediaJobsDTO: Decodable {
    let jobs: [MediaJobDTO]
}

private nonisolated struct MediaJobDTO: Decodable {
    let jobId: String
    let kind: String
    let status: String
    let assets: [MediaJobAssetDTO]
    /// Чем и по какому запросу сделана — для повтора генерации.
    let model: String?
    let prompt: String?
}

private nonisolated struct MediaJobAssetDTO: Decodable {
    let url: String
}
