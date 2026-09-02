import SwiftUI

/// Пейвол пакетов токенов — «Buy more tokens».
///
/// Устроен как пейвол подписки, но пакеты расходуемые: платформа хранит их баланс
/// на сервере, и локальный кеш никогда не считается источником купленного.
struct TokenPaywallScreen: View {
    let packages: [PaywallPlan]
    var isPurchasing: Bool = false
    var isRestoring: Bool = false

    /// Позиция выбранного пакета в списке — см. пояснение в `ProPaywallScreen`.
    @Binding var selectedIndex: Int?

    /// Выбор действителен, только если позиция есть в списке — каталог может прийти пустым.
    private var hasValidSelection: Bool {
        guard let selectedIndex else { return false }
        return packages.indices.contains(selectedIndex)
    }
    let onContinue: () -> Void
    let onClose: () -> Void
    let onRestore: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenTermsOfUse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Арт стоит в стеке, а не фоном: количество продуктов задаёт Adapty,
            // и при лишней карточке фоновая картинка оказывалась под контентом.
            // Свечение при этом на раскладку по-прежнему не влияет — оно внутри
            // `AccentGlow` построено на гибком `Color.clear`.
            TopArtwork(
                imageName: "TokenCoins",
                glowSize: CGSize(width: 622, height: 404),
                glowCenterY: 282,
                imageTopPadding: 70,
                fitsAvailableSpace: true
            )
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        // Предвыбор и защита от перезагрузки каталога — см. `ProPaywallScreen`.
        .onChange(of: packages.count, initial: true) { _, count in
            guard let index = selectedIndex, index < count else {
                selectedIndex = packages.indices.first
                return
            }
        }
        .overlay(alignment: .topLeading) {
            CircleIconButton(
                systemImage: "xmark",
                accessibilityLabel: "Close",
                glyph: AppFont.Icon.large,
                action: onClose
            )
            .padding(.leading, AppMetrics.screenPadding)
            // Тот же отступ от статус-бара, что и у шапки остальных экранов.
            .padding(.top, Spacing.reg)
        }
    }

    private var bottomBlock: some View {
        VStack(spacing: Spacing.reg) {
            Text("Buy more tokens")
                .appTextStyle(AppFont.h2)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textPrimary)

            if !packages.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(packages.enumerated()), id: \.offset) { index, package in
                        PlanRow(plan: package, isSelected: index == selectedIndex) {
                            selectedIndex = index
                        }
                        // См. `ProPaywallScreen`: место под выступ плашки.
                        .padding(.top, index > 0 && package.badge != nil ? AppMetrics.badgeRise : 0)
                    }
                }
            }

            VStack(spacing: Spacing.xs) {
                PrimaryButton(
                    title: String(localized: "Continue"),
                    isInFlight: isPurchasing,
                    isEnabled: hasValidSelection,
                    action: onContinue
                )

                LegalFooter(
                    onPrivacyPolicy: onOpenPrivacyPolicy,
                    onRestore: onRestore,
                    onTermsOfUse: onOpenTermsOfUse,
                    isRestoring: isRestoring
                )
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, AppMetrics.screenPadding)
        .bottomScrim(solidAt: 0.3)
    }
}

#Preview {
    @Previewable @State var selected: Int? = 0

    TokenPaywallScreen(
        packages: PreviewData.tokenPackages,
        selectedIndex: $selected,
        onContinue: {}, onClose: {}, onRestore: {},
        onOpenPrivacyPolicy: {}, onOpenTermsOfUse: {}
    )
}
