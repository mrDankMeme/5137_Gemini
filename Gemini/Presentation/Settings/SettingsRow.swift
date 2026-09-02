import SwiftUI

/// Строка настроек: иконка, название и правый элемент.
///
/// В макете строка одна и та же во всех трёх группах — меняется только то,
/// что стоит справа: шеврон, переключатель или значение со шевроном.
struct SettingsRow<Trailing: View>: View {
    /// `LocalizedStringKey`, а не `String`: подписи строк — всегда литералы,
    /// и так они попадают в каталог сами, без обёртки в каждом вызове.
    let title: LocalizedStringKey
    let systemImage: String
    var isDestructive: Bool = false
    @ViewBuilder var trailing: Trailing
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: systemImage)
                .font(AppFont.Icon.regular)
                .foregroundStyle(isDestructive ? AppColor.error : AppColor.textPrimary)
                .frame(width: AppMetrics.compactButton, height: AppMetrics.settingsRow)
                .padding(.leading, Spacing.reg)

            Text(title)
                .appTextStyle(AppFont.row)
                // В макете названия строк приглушены до `Text/white 50` —
                // яркими остаются только иконки и заголовки групп.
                .foregroundStyle(isDestructive ? AppColor.error : AppColor.textTertiary)

            Spacer(minLength: 8)

            trailing
        }
        .padding(.trailing, Spacing.reg)
        .frame(minHeight: AppMetrics.tapTarget)
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.xxxl))
        .contentShape(.rect(cornerRadius: Radius.xxxl))
    }
}

/// Шеврон строки настроек. Отдельным вью, чтобы стиль из макета
/// (`#EBEBF5` 30%, 17 semibold) жил в одном месте: строк с ним несколько.
struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(AppFont.Icon.chevron)
            .foregroundStyle(AppColor.rowChevron)
    }
}

extension SettingsRow where Trailing == SettingsChevron {
    /// Строка-переход: справа шеврон.
    init(
        title: LocalizedStringKey,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            isDestructive: isDestructive,
            trailing: { SettingsChevron() },
            action: action
        )
    }
}

/// Группа строк с заголовком.
struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .appTextStyle(AppFont.rowTitle)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, Spacing.reg)
                .padding(.bottom, 6)

            content
        }
    }
}
