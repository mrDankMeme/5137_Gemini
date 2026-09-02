import SwiftUI

/// Нижняя строка онбординга и пейволов: Privacy Policy • Restore • Terms of Use.
///
/// В макете разделитель — отдельный текстовый узел «•» того же стиля,
/// а вся строка набрана 14/21 цветом `#B9BABA`.
struct LegalFooter: View {
    let onPrivacyPolicy: () -> Void
    let onRestore: () -> Void
    let onTermsOfUse: () -> Void
    var isRestoring: Bool = false
    /// В онбординге строка белая, на пейволах — приглушённая.
    var tint: Color = AppColor.textMuted

    var body: some View {
        HStack(spacing: Spacing.sm) {
            link(Self.privacyTitle, action: onPrivacyPolicy)
            separator
            restoreLink
            separator
            link(Self.termsTitle, action: onTermsOfUse)
        }
        .frame(minHeight: AppMetrics.tapTarget)
        .appTextStyle(AppFont.caption)
        .foregroundStyle(tint)
    }

    private var separator: some View {
        Text(verbatim: "•")
            .accessibilityHidden(true)
    }

    private var restoreLink: some View {
        Button(action: onRestore) {
            if isRestoring {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(tint)
            } else {
                Text(Self.restoreTitle)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .frame(minHeight: AppMetrics.tapTarget)
        .contentShape(.rect)
    }

    // Свои ключи, а не общие «Privacy Policy» / «Terms of Use» из настроек:
    // три ссылки с разделителями стоят в одну строку на 402 pt, и полные
    // «Политика конфиденциальности» с «Условиями использования» туда не влезают.
    // Английские подписи при этом те же, что в макете.
    private static let privacyTitle = String(localized: "legalFooter.privacyPolicy",
                                             defaultValue: "Privacy Policy")
    private static let termsTitle = String(localized: "legalFooter.termsOfUse",
                                           defaultValue: "Terms of Use")
    private static let restoreTitle = String(localized: "legalFooter.restore",
                                             defaultValue: "Restore")

    /// Высота 44 pt нужна каждой ссылке отдельно: если задать её только стеку,
    /// нажимается лишь строка текста высотой ~17 pt.
    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .frame(minHeight: AppMetrics.tapTarget)
            .contentShape(.rect)
    }
}

#Preview {
    LegalFooter(onPrivacyPolicy: {}, onRestore: {}, onTermsOfUse: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
}
