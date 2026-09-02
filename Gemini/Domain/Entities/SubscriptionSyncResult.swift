import Foundation

/// Ответ `/v1/subscription/sync` — статус подписки на сервере после проверки
/// подписанной Apple-транзакции.
struct SubscriptionSyncResult: Decodable, Sendable {
    let isSubscribed: Bool
    let expiresAt: Date?
}
