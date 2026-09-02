/// Загрузка каталога моделей.
struct LoadModelsUseCase: Sendable {
    private let repository: any ModelCatalogRepositoryProtocol

    init(repository: any ModelCatalogRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [AIModel] {
        try await repository.loadModels()
    }
}

/// Данные аккаунта: идентификатор и баланс токенов.
struct LoadAccountUseCase: Sendable {
    private let repository: any AccountRepositoryProtocol

    init(repository: any AccountRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction() async throws -> Account {
        async let id = repository.loadAccountID()
        async let policy = repository.loadPolicy()
        let (balance, isSubscribed) = try await policy
        return try await Account(id: id, tokenBalance: balance, isSubscribedOnBackend: isSubscribed)
    }
}
