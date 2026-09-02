import BroadCore
import Foundation

/// Согласие на обработку сообщений, фото и файлов через ИИ.
///
/// Тот же приём, что в 5135/5136: один раз за установку, до первой отправки —
/// текста в чат или запроса на генерацию, смотря что раньше. Отказ не тупик:
/// пользователь листает приложение дальше и увидит экран снова, как только
/// попробует отправить что-то в первый раз.
///
/// Хранится момент согласия, а не только факт: письму в поддержку есть что
/// показать — «когда именно согласились», а не просто «когда-то да». Второе
/// согласие дату не переставляет — считается первое.
struct AIConsentPolicy: Sendable {
    private static let key = "ai-consent.accepted-at.v1"

    private let store: any KeyValueStoreProtocol

    init(store: any KeyValueStoreProtocol) {
        self.store = store
    }

    func acceptedAt() async -> Date? {
        guard case let .data(stored) = try? await store.read(Self.key) else { return nil }
        return try? JSONDecoder().decode(Date.self, from: stored)
    }

    func hasAccepted() async -> Bool {
        await acceptedAt() != nil
    }

    func accept() async {
        guard await acceptedAt() == nil else { return }
        guard let data = try? JSONEncoder().encode(Date()) else { return }
        try? await store.write(data, forKey: Self.key)
    }
}
