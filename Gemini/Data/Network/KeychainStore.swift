import Foundation
import Security

/// Хранилище секретов в Keychain.
///
/// Именно Keychain, а не хранилище настроек: refresh-токен живёт 30 дней
/// и даёт доступ к аккаунту, а настройки уезжают в бэкапы открытым текстом.
/// Идентификатор устройства тоже здесь — он переживает переустановку,
/// и пользователь не теряет свои чаты и баланс.
nonisolated struct KeychainStore: Sendable {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func string(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// `false` — не сохранилось. Раньше статус выбрасывался, и молчаливый
    /// отказ Keychain выглядел как «приложение теряет аккаунт на ровном месте»:
    /// без идентификатора устройства каждый запуск заводил нового пользователя,
    /// а вместе с ним новый баланс, подписку и историю.
    @discardableResult
    func set(_ value: String?, for key: String) -> Bool {
        guard let value, let data = value.data(using: .utf8) else {
            let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updated == errSecItemNotFound else { return updated == errSecSuccess }

        var insert = query
        insert[kSecValueData as String] = data
        // Секрет нужен и в фоне — иначе восстановление сессии после
        // перезапуска упирается в заблокированный экран.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
