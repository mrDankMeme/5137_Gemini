import BroadCore
import Foundation

/// Когда показывать спецпредложение.
///
/// Правило дома, как в 232 (`DiscountOfferManager`): предложение всплывает
/// **после закрытия пейвола**, пока открыто окно кампании. Окно заводится в
/// момент первого показа и живёт столько, сколько задал продакт в remote config
/// пейвола; по умолчанию сутки. Когда окно истекло, предложение больше
/// не показывается — иначе таймер на экране врал бы.
///
/// Гейт кампании (`special_offer` в remote config) проверяет вызывающая
/// сторона: это не про время, а про то, включена ли кампания вообще.
struct SpecialOfferPolicy: Sendable {
    private static let key = "special-offer.window-end.v1"
    private static let defaultWindow: TimeInterval = 24 * 3600

    private let store: any KeyValueStoreProtocol

    init(store: any KeyValueStoreProtocol) {
        self.store = store
    }

    /// Окно ещё не открывали или оно не истекло.
    func hasActiveWindow(now: Date = Date()) async -> Bool {
        guard let end = await windowEnd() else {
            return true
        }
        return now < end
    }

    /// Заводит окно один раз. Повторный вызов ничего не меняет — иначе каждый
    /// показ продлевал бы кампанию бесконечно.
    func beginWindowIfNeeded(duration: TimeInterval?, now: Date = Date()) async -> Date {
        if let end = await windowEnd() {
            return end
        }
        let end = now.addingTimeInterval(duration ?? Self.defaultWindow)
        if let data = try? JSONEncoder().encode(end) {
            try? await store.write(data, forKey: Self.key)
        }
        return end
    }

    private func windowEnd() async -> Date? {
        guard let entry = try? await store.read(Self.key),
              case let .data(data) = entry
        else {
            return nil
        }
        return try? JSONDecoder().decode(Date.self, from: data)
    }
}
