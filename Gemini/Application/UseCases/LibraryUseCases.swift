/// Загрузка библиотеки генераций.
struct LoadLibraryUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [LibraryItem] {
        try await repository.loadItems()
    }
}

/// Сохранение генерации в библиотеку.
struct SaveGenerationUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(_ item: LibraryItem) async throws {
        try await repository.save(item)
    }
}

/// Удаление генерации.
struct DeleteGenerationUseCase: Sendable {
    private let repository: any LibraryRepositoryProtocol

    init(repository: any LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(_ item: LibraryItem) async throws {
        try await repository.delete(item)
    }
}
