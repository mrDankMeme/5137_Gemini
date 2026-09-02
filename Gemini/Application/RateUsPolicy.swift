import BroadCore
import Foundation

/// Когда показывать собственный попап «Rate Us».
///
/// Правило дома, то же что у 232: **один раз за установку, после успешного
/// ответа** — то есть после целевого действия, когда пользователю уже есть
/// что оценивать. До этого просить оценку не за что. Показ — тот же
/// `RateUsPopup`, что и у ручной строки «Rate app» в настройках, а не
/// полноэкранный `RateUsScreen`: тот слишком тяжёл для момента, который
/// пользователь сам не запрашивал.
///
/// Порог разный для подписчика и для пробного пользователя. Подписчику —
/// не после самого первого: попап всё равно перекрывает часть экрана, и на
/// первом же ответе это читалось бы как помеха ровно тому тексту, ради
/// которого пользователь пришёл. Ждём второго: к этому моменту один ответ
/// прочитан и человек вернулся спросить ещё, что само по себе сигнал лучше
/// первого запроса.
///
/// Без подписки второго ответа не будет вовсе: бесплатное сообщение одно,
/// дальше бэкенд отвечает `trial_used` и открывается пейвол — тот же приём,
/// что `presentRateDialogAfterFreeChatMessageIfNeeded` у 232. Ждать здесь
/// нечего, спрашиваем после первого же ответа.
///
/// Внутри онбординга не показывается никогда — там его запрещает платформа,
/// и звать политику оттуда некому: она живёт в основной сцене.
///
/// Отметка кладётся в хранилище платформы, а не в `UserDefaults` напрямую:
/// прямое обращение запрещено правилами архитектуры.
struct RateUsPolicy: Sendable {
    private static let key = "rate-us.prompted-after-first-success.v1"
    private static let counterKey = "rate-us.successful-replies.v1"
    private static let marker = Data([1])
    /// После какого по счёту успешного ответа спрашивать подписчика.
    private static let promptAfterSubscribed = 2
    /// Без подписки — сразу после единственного пробного ответа.
    private static let promptAfterFree = 1

    private let store: any KeyValueStoreProtocol

    init(store: any KeyValueStoreProtocol) {
        self.store = store
    }

    /// Зовётся на каждый успешный ответ и сама считает, который он по счёту.
    ///
    /// `true` — показать сейчас. Отметку ставит сама: второй раз не вернёт `true`,
    /// даже если показ почему-то не состоялся. Это осознанно — навязываться
    /// повторно хуже, чем не показать один раз.
    func shouldPrompt(isSubscribed: Bool) async -> Bool {
        // Ошибка чтения — не повод спрашивать оценку: молчим.
        guard let entry = try? await store.read(Self.key), entry == .missing else {
            return false
        }

        let replies = await count() + 1
        try? await store.write(Data([UInt8(min(replies, 255))]), forKey: Self.counterKey)
        let threshold = isSubscribed ? Self.promptAfterSubscribed : Self.promptAfterFree
        guard replies >= threshold else { return false }

        try? await store.write(Self.marker, forKey: Self.key)
        return true
    }

    private func count() async -> Int {
        guard case let .data(stored) = try? await store.read(Self.counterKey),
              let first = stored.first
        else {
            return 0
        }
        return Int(first)
    }
}
