import Foundation

/// Ответ `/v1/tokens/purchase` — начисление уже идемпотентно на сервере,
/// повторный вызов с той же транзакцией просто вернёт `creditsAdded == 0`.
struct TokenPurchaseResult: Decodable, Sendable {
    let creditsAdded: Decimal
    let newBalance: Decimal
    let transactionID: String

    private enum CodingKeys: String, CodingKey {
        case creditsAdded
        case newBalance
        case transactionID = "transactionId"
    }
}
