import SwiftUI

/// Пустое состояние списка: заголовок и подсказка по центру экрана.
struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Spacer()

            Text(title)
                .appTextStyle(AppFont.bodyMedium)
                .foregroundStyle(AppColor.textPrimary)

            Text(message)
                .appTextStyle(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)

            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppMetrics.screenPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
