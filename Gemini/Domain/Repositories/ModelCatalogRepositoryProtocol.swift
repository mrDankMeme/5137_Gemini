/// Каталог доступных моделей генерации.
protocol ModelCatalogRepositoryProtocol: Sendable {
    func loadModels() async throws -> [AIModel]
}
