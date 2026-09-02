import Foundation

/// Идентификатор устройства, к которому привязан аккаунт на backend.
///
/// Не `identifierForVendor`: тот обнуляется, когда пользователь удаляет все
/// приложения вендора, и аккаунт вместе с балансом, подпиской и историей
/// теряется без единого следа.
///
/// Хранится в Keychain, но **не только** в нём. Живьём наблюдалось, как
/// приложение заводит нового пользователя на каждом запуске: Keychain молча
/// не отдавал записанное, идентификатор генерировался заново, и сервер честно
/// выдавал новый аккаунт на новое устройство. Один источник, который может
/// отказать молча, — слишком хрупко для единственного, что связывает человека
/// с его покупками.
///
/// Поэтому копия лежит файлом в `Application Support` с защитой
/// «до первой разблокировки» — той же, что у записи в Keychain. Идентификатор
/// не секрет пользователя, а непрозрачная случайная строка; refresh-токен
/// по-прежнему живёт только в Keychain.
nonisolated struct DeviceIdentityStore: Sendable {
    private static let key = "device.id"
    private static let fileName = "device-identity"

    private let keychain: KeychainStore
    private let fileURL: URL

    init(keychain: KeychainStore, fileName: String = DeviceIdentityStore.fileName) {
        self.keychain = keychain
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = directory.appendingPathComponent(fileName)
    }

    /// Существующий идентификатор или новый, если его нет ни в одном хранилище.
    func identity() -> String {
        if let stored = keychain.string(for: Self.key) {
            // Keychain — источник правды; файл мог отстать после переустановки.
            writeFile(stored)
            return stored
        }
        if let stored = readFile() {
            // Keychain потерял запись, но аккаунт терять из-за этого нельзя.
            keychain.set(stored, for: Self.key)
            return stored
        }

        let generated = "gemini5137-" + UUID().uuidString
        keychain.set(generated, for: Self.key)
        writeFile(generated)
        return generated
    }

    // MARK: Файл

    private func readFile() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private func writeFile(_ value: String) {
        guard readFile() != value else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? value.data(using: .utf8)?.write(to: fileURL, options: .atomic)
        // Та же доступность, что у записи в Keychain: сессия восстанавливается
        // и до того, как пользователь разблокировал экран после перезагрузки.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
    }
}
