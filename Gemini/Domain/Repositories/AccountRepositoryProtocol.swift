import Foundation

/// Данные текущего аккаунта: идентификатор и баланс токенов.
protocol AccountRepositoryProtocol: Sendable {
    /// Идентификатор аккаунта — его диктуют поддержке.
    func loadAccountID() async throws -> String

    /// Баланс токенов и признак подписки — одним запросом, из одного ответа
    /// `/v1/policy/effective`. Источник правды по балансу — сервер, локальный
    /// кеш им не считается.
    func loadPolicy() async throws -> (balance: Decimal, isSubscribed: Bool)
}
