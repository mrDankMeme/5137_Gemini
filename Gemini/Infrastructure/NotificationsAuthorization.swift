import UIKit
import UserNotifications

/// Переключатель уведомлений в настройках.
///
/// Разрешение выдаёт система, а не приложение, поэтому переключатель не хранит
/// собственное значение: он показывает **фактическое** состояние и, в зависимости
/// от него, либо запрашивает разрешение, либо ведёт в системные настройки.
/// Иначе тумблер показывал бы «включено» при выключенных уведомлениях в iOS.
@Observable
@MainActor
final class NotificationsAuthorization {
    private(set) var isEnabled = false
    private(set) var isRequestInFlight = false

    private let center = UNUserNotificationCenter.current()

    func refresh() async {
        let settings = await center.notificationSettings()
        isEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Возвращает адрес системных настроек, если разрешение уже спрашивали
    /// и изменить его внутри приложения нельзя.
    func toggle() async -> URL? {
        guard !isRequestInFlight else { return nil }
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            isEnabled = granted
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return nil

        default:
            // Разрешение уже выдано или отклонено — менять его можно только в iOS.
            return URL(string: UIApplication.openSettingsURLString)
        }
    }
}
