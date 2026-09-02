import SwiftUI

/// Попап необязательного обновления.
///
/// Дизайнер отметил его как «можно скипнуть», поэтому кнопка Skip обязательна
/// и закрывает попап без последствий.
struct AppUpdateSheet: View {
    let onUpdate: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            AppMark(size: 140)

            // В макете между заголовком и подписью 12, а не 8.
            VStack(spacing: Spacing.sm) {
                Text("App update Available")
                    .appTextStyle(AppFont.h2)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Update now for faster, more stable performance")
                    .appTextStyle(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Spacing.xs) {
                PrimaryButton(title: String(localized: "Update"), action: onUpdate)

                Button("Skip", action: onSkip)
                    .buttonStyle(.plain)
                    .appTextStyle(AppFont.button)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(height: AppMetrics.tapTarget)
            }
        }
        // Отступ сверху 40 — под полоску захвата, как в макете.
        .padding(.top, 40)
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.bottom, Spacing.reg)
        .frame(maxWidth: .infinity)
        .background(AppColor.bgSecondary)
        .presentationDetents([.height(AppMetrics.appUpdateSheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.bgSecondary)
        .presentationCornerRadius(AppMetrics.sheetRadius)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AppUpdateSheet(onUpdate: {}, onSkip: {})
    }
}
