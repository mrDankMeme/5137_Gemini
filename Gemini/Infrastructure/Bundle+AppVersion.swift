import Foundation

extension Bundle {
    /// Версия приложения для экрана настроек — «1.0.0».
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
