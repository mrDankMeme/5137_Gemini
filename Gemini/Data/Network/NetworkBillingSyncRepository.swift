struct NetworkBillingSyncRepository: BillingSyncRepositoryProtocol {
    private struct TransactionSyncBody: Encodable {
        let userId: String
        let transaction: String
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func syncSubscription(userID: String, transactionJWS: String) async throws -> SubscriptionSyncResult {
        try await client.post(
            "/v1/subscription/sync",
            body: TransactionSyncBody(userId: userID, transaction: transactionJWS)
        )
    }

    func purchaseTokens(userID: String, transactionJWS: String) async throws -> TokenPurchaseResult {
        try await client.post(
            "/v1/tokens/purchase",
            body: TransactionSyncBody(userId: userID, transaction: transactionJWS)
        )
    }
}
