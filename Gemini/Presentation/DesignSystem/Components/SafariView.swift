import SafariServices
import SwiftUI

/// Открывает ссылку **внутри приложения**, а не выбрасывает в Safari.
///
/// Так во всех приложениях компании: политика и условия — часть покупки,
/// и выкидывать человека из пейвола ради их чтения нельзя, обратно он может
/// и не вернуться.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

extension View {
    /// Вешается на тот экран, с которого открыли ссылку, а не на корень сцены:
    /// пейволы показываются полноэкранным окном, и шторка с корня оказалась бы
    /// под ним.
    func policyLinkSheet(url: Binding<URL?>) -> some View {
        sheet(item: url) { SafariView(url: $0) }
    }
}
