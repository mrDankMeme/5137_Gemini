import SwiftUI

/// Переключатель модели в шапке: «Gemini 2.5 Flash ⌄».
struct ModelChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Text(title)
                    .appTextStyle(AppFont.footnoteMedium)
                    .foregroundStyle(AppColor.textPrimary)

                Image(systemName: "chevron.down")
                    .font(AppFont.Icon.small)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(AppColor.bgSecondary, in: .rect(cornerRadius: AppMetrics.badgeRadius))
            // Капсула в макете всего 25 pt высотой — нажимать её так тяжело,
            // поэтому область попадания расширена до 44 pt.
            .frame(minHeight: AppMetrics.tapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Model: \(title)")
        .accessibilityHint("Choose a different model")
    }
}
