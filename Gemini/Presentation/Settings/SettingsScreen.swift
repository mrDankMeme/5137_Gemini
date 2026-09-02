import SwiftUI
import UIKit

/// Настройки. Состав и порядок строк — из макета.
struct SettingsScreen: View {
    let balance: ProButton.Content
    let cacheSize: String
    let accountID: String
    let appVersion: String

    var isRestoring: Bool = false
    var isClearingCache: Bool = false

    let onBack: () -> Void
    let onOpenPaywall: () -> Void
    /// См. `HomeScreen.onOpenBalance`: у кнопки в шапке своё назначение,
    /// а строка «Upgrade plan» всегда ведёт к подписке.
    let onOpenBalance: () -> Void
    let onRateApp: () -> Void
    let onShare: () -> Void
    let onClearCache: () -> Void
    let onRestorePurchases: () -> Void
    let onContactUs: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenUsagePolicy: () -> Void
    let onOpenLanguage: () -> Void

    @State private var notifications = NotificationsAuthorization()
    @State private var isAccountIDCopied = false
    @Environment(\.openURL) private var openURL
    @Environment(\.showToast) private var showToast
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: String(localized: "Settings")) {
                CircleIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Back",
                    action: onBack
                )
            } trailing: {
                ProButton(content: balance, action: onOpenBalance)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.reg) {
                    supportGroup
                    purchasesGroup
                    legalGroup
                    footer
                }
                .padding(.horizontal, AppMetrics.screenPadding)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        .task { await notifications.refresh() }
        // Пользователь мог поменять разрешение в системных настройках и вернуться.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await notifications.refresh() }
        }
    }

    private var supportGroup: some View {
        SettingsGroup(title: "Support us") {
            VStack(spacing: Spacing.xs) {
                SettingsRow(title: "Rate app", systemImage: "star", action: onRateApp)
                SettingsRow(title: "Share with friends", systemImage: "square.and.arrow.up", action: onShare)
            }
        }
    }

    private var purchasesGroup: some View {
        SettingsGroup(title: "Purchases & Actions") {
            VStack(spacing: Spacing.xs) {
                // Подписчику предлагать оформить подписку незачем: строка вела
                // на «Go Pro», который ему уже не нужен и купить с него нечего.
                // `.pro` — не единственное подписное состояние бейджа:
                // с токенами он показывает их число, а не «Pro».
                if balance == .upgrade {
                    SettingsRow(title: "Upgrade plan", systemImage: "sparkles", action: onOpenPaywall)
                }

                SettingsRow(title: "Notifications", systemImage: "bell") {
                    // `Text(verbatim:)`, иначе компилятор вытаскивает пустую
                    // строку в каталог отдельным ключом «».
                    Toggle(isOn: Binding(
                        get: { notifications.isEnabled },
                        set: { _ in requestNotifications() }
                    )) {
                        Text(verbatim: "")
                    }
                    .labelsHidden()
                    .tint(AppColor.accent)
                    .disabled(notifications.isRequestInFlight)
                }

                SettingsRow(title: "Clear cache", systemImage: "trash") {
                    HStack(spacing: Spacing.xxs) {
                        if isClearingCache {
                            ProgressView().tint(AppColor.textSecondary)
                        } else {
                            Text(cacheSize)
                                .appTextStyle(AppFont.row)
                                .foregroundStyle(AppColor.rowDetail)
                        }
                        SettingsChevron()
                    }
                } action: {
                    onClearCache()
                }

                SettingsRow(title: "Restore purchases", systemImage: "arrow.clockwise.icloud") {
                    if isRestoring {
                        ProgressView().tint(AppColor.textSecondary)
                    } else {
                        // Тот же шеврон, что у остальных строк. Голый
                        // `Image` брал цвет по умолчанию и был заметно ярче
                        // соседей — единственная строка не в ряд.
                        SettingsChevron()
                    }
                } action: {
                    onRestorePurchases()
                }

                // «Subscription management» убрано до появления RU-платежей:
                // сейчас за ним стоит только экран текущего тарифа, а сам тариф
                // виден и без него. Вернуть вместе с российской платёжкой.
            }
        }
    }

    private var legalGroup: some View {
        SettingsGroup(title: "Info & legal") {
            VStack(spacing: Spacing.xs) {
                // Usedesk (строка «Support Chat») намеренно не показываем в И1:
                // Company ID и Channel ID ещё не выданы, и вести строке некуда —
                // мёртвая кнопка хуже отсутствующей. Подключим в следующих версиях;
                // возврат — одна строка, как только придут данные.
                SettingsRow(title: "Contact us", systemImage: "envelope", action: onContactUs)
                SettingsRow(title: "Privacy Policy", systemImage: "lock.doc", action: onOpenPrivacyPolicy)
                SettingsRow(title: "Usage Policy", systemImage: "doc.text", action: onOpenUsagePolicy)
                SettingsRow(title: "Language", systemImage: "globe", action: onOpenLanguage)
            }
        }
    }

    private func copyAccountID() {
        UIPasteboard.general.string = accountID
        // Тост называет, что именно скопировано: галочка на иконке говорит
        // «сработало», но не «что».
        showToast(.copied(String(localized: "Account ID copied")))
        withAnimation(.easeOut(duration: 0.15)) { isAccountIDCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.15)) { isAccountIDCopied = false }
        }
    }

    /// Разрешение выдаёт система: либо спрашиваем впервые, либо ведём в настройки iOS.
    private func requestNotifications() {
        Task {
            if let settingsURL = await notifications.toggle() {
                openURL(settingsURL)
            }
        }
    }

    /// Идентификатор аккаунта рядом с кнопкой копирования — так в макете:
    /// его диктуют поддержке, поэтому набирать вручную неудобно.
    /// В строке — только начало идентификатора, как в 232: полный это UUID
    /// в 36 знаков, он переносится на вторую строку и разъезжает подпись под
    /// собой. Кнопка при этом кладёт в буфер идентификатор целиком — короткого
    /// поддержке не хватит.
    private var truncatedAccountID: String {
        String(accountID.prefix(8))
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Account ID: \(truncatedAccountID)")

                Button(action: copyAccountID) {
                    Image(systemName: isAccountIDCopied ? "checkmark" : "doc.on.doc")
                        .font(AppFont.Icon.footnote)
                        .contentTransition(.symbolEffect(.replace))
                        // Нажимается 44×44, но в раскладке кнопка занимает высоту
                        // строки: иначе подпись под ID разъезжается на 20 pt.
                        .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget)
                        .contentShape(.rect)
                        .frame(height: AppMetrics.icon)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: isAccountIDCopied)
                .accessibilityLabel("Copy account ID")
            }

            Text("App Version: \(appVersion)")
        }
        .appTextStyle(AppFont.footnoteSmall)
        .foregroundStyle(AppColor.textTertiary)
        .padding(.horizontal, Spacing.reg)
        .padding(.top, Spacing.xs)
        // В макете обе строки по центру экрана, а не по левому краю.
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SettingsScreen(
        balance: .tokenBalance(500),
        cacheSize: "5 MB",
        accountID: "10101010",
        appVersion: "1.0.0",
        onBack: {}, onOpenPaywall: {}, onOpenBalance: {}, onRateApp: {}, onShare: {}, onClearCache: {},
        onRestorePurchases: {},
        onContactUs: {}, onOpenPrivacyPolicy: {}, onOpenUsagePolicy: {}, onOpenLanguage: {}
    )
}
