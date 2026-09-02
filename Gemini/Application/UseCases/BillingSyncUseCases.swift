/// Репорт подписки бэку после покупки/на каждом холодном старте — идемпотентно,
/// звать безопасно сколько угодно раз.
struct SyncSubscriptionUseCase: Sendable {
    private let repository: any BillingSyncRepositoryProtocol

    init(repository: any BillingSyncRepositoryProtocol) {
        self.repository = repository
    }

    @discardableResult
    func callAsFunction(userID: String, transactionJWS: String) async throws -> SubscriptionSyncResult {
        try await repository.syncSubscription(userID: userID, transactionJWS: transactionJWS)
    }
}

/// Репорт покупки токен-пакета бэку — идемпотентно, ответ несёт новый баланс.
struct PurchaseTokensSyncUseCase: Sendable {
    private let repository: any BillingSyncRepositoryProtocol

    init(repository: any BillingSyncRepositoryProtocol) {
        self.repository = repository
    }

    @discardableResult
    func callAsFunction(userID: String, transactionJWS: String) async throws -> TokenPurchaseResult {
        try await repository.purchaseTokens(userID: userID, transactionJWS: transactionJWS)
    }
}
