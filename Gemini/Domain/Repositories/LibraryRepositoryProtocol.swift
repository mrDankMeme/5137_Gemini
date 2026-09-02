/// Библиотека сохранённых генераций.
protocol LibraryRepositoryProtocol: Sendable {
    func loadItems() async throws -> [LibraryItem]

    /// Сохраняет генерацию в библиотеку.
    ///
    /// По макету сохранение стоит токенов, но списывает их сервер: локальный
    /// баланс не является доказательством оплаты, поэтому решение о списании
    /// принимается не здесь.
    func save(_ item: LibraryItem) async throws

    func delete(_ item: LibraryItem) async throws
}
