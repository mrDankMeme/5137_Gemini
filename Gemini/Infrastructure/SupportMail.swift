import MessageUI
import SwiftUI
import UIKit

/// Письмо в поддержку.
///
/// Именно письмо, а не гугл-форма: у формы нет ни идентификаторов, ни версии
/// сборки — поддержке приходится выспрашивать их у человека, который уже
/// расстроен. В письме всё это уже проставлено, остаётся описать проблему.
/// Так же сделано в 232 и 5131.
struct SupportMailData: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
}

enum SupportMail {
    /// Собирает письмо: тема, диагностика и место под описание проблемы.
    static func make(accountID: String, balance: String, isSubscribed: Bool) -> SupportMailData {
        let info = Bundle.main.infoDictionary
        let version = value(info?["CFBundleShortVersionString"] as? String)
        let build = value(info?["CFBundleVersion"] as? String)
        let bundle = value(Bundle.main.bundleIdentifier)
        let appName = value(info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String)

        let body = """
        Hi! I need help with the app.

        --- App info ---
        App: \(appName)
        Installed: \(version) (\(build))
        Bundle: \(bundle)

        --- Device ---
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        Locale: \(Locale.current.identifier)
        TimeZone: \(TimeZone.current.identifier)

        --- Account ---
        Account ID: \(value(accountID))
        Balance: \(value(balance))
        Subscription: \(isSubscribed ? "subscribed" : "not_subscribed")

        --- Describe the problem below ---


        """

        return SupportMailData(subject: "\(appName) — Support", body: body)
    }

    /// Есть ли на устройстве настроенная почта. Нет — открываем `mailto:`,
    /// его подхватит сторонний почтовый клиент.
    static var canComposeInApp: Bool {
        MFMailComposeViewController.canSendMail()
    }

    static func mailtoURL(_ data: SupportMailData, to address: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: data.subject),
            URLQueryItem(name: "body", value: data.body),
        ]
        return components.url
    }

    private static func value(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "unknown" }
        return raw
    }
}

/// Системный редактор письма. Обёртка нужна, потому что SwiftUI своего
/// редактора не даёт, а `mailto:` уводит из приложения.
struct MailComposeView: UIViewControllerRepresentable {
    let address: String
    let data: SupportMailData
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([address])
        controller.setSubject(data.subject)
        controller.setMessageBody(data.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_: MFMailComposeViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _: MFMailComposeViewController,
            didFinishWith _: MFMailComposeResult,
            error _: Error?
        ) {
            onFinish()
        }
    }
}
