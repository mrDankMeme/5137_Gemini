import StoreKit

/// Достаёт подписанную Apple-транзакцию (JWS) напрямую из StoreKit — независимо
/// от Adapty. Именно её бэк проверяет по подписи Apple: передавать что-то своё
/// вместо неё бессмысленно.
enum StoreKitTransactionProvider {
    /// Ищет среди текущих активных прав подписку с одним из наших SKU.
    static func latestSubscriptionJWS(productIDs: [String]) async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  productIDs.contains(transaction.productID)
            else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    /// Последняя транзакция по конкретному расходуемому продукту (пакет токенов).
    static func latestJWS(for productID: String) async -> String? {
        guard let result = await Transaction.latest(for: productID),
              case .verified = result
        else {
            return nil
        }
        return result.jwsRepresentation
    }
}
