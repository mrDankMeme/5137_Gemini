/// Репорт покупки на бэк подписанной StoreKit-транзакцией.
///
/// Нужен, даже несмотря на вебхук Adapty → бэк: вебхук асинхронный и может
/// не долететь, а без записи на бэке сразу после покупки пользователь платит
/// и тут же получает отказ там, где сервер уже должен видеть Pro/баланс.
/// Тот же паттерн, что у 232 (`BillingService.syncSubscription`/`purchaseTokens`) —
/// тот же бэкенд-сервис, другая конфигурация.
protocol BillingSyncRepositoryProtocol: Sendable {
    func syncSubscription(userID: String, transactionJWS: String) async throws -> SubscriptionSyncResult
    func purchaseTokens(userID: String, transactionJWS: String) async throws -> TokenPurchaseResult
}
