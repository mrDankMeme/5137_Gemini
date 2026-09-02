import StoreKit
import UIKit

/// Единственное место, где приложение просит системную оценку.
///
/// Правило платформы: нативные review-API живут только в выделенном адаптере.
/// Экраны про StoreKit не знают — они вызывают `ReviewAdapter.request()`.
///
/// Внутри онбординга этот вызов запрещён: платформа разрешает Rate Us
/// только в самом приложении.
@MainActor
enum ReviewAdapter {
    static func request() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return
        }

        AppStore.requestReview(in: scene)
    }
}
