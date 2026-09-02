import SwiftUI

/// Просьба оценить приложение.
///
/// Показывается **только внутри приложения** — платформа прямо запрещает
/// Rate Us внутри онбординга, поэтому этот экран туда не подключается.
struct RateUsScreen: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) {
            // Числа из макета: эллипс 622×560 с центром на y=370, звезда с отступа 101.
            TopArtwork(
                imageName: "RateStar",
                glowSize: CGSize(width: 622, height: 560),
                glowCenterY: 370,
                imageTopPadding: 101
            )
        }
        .background(AppColor.bgPrimary)
    }

    private var bottomBlock: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("Enjoying the App?")
                    .appTextStyle(AppFont.h2)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Leave a rating and help us make it even better")
                    .appTextStyle(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Spacing.xs) {
                PrimaryButton(title: String(localized: "Continue"), action: onContinue)

                Button("Skip", action: onSkip)
                    .buttonStyle(.plain)
                    .appTextStyle(AppFont.button)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(height: AppMetrics.tapTarget)
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, AppMetrics.screenPadding)
        .bottomScrim(solidAt: 0.5)
    }
}

#Preview {
    RateUsScreen(onContinue: {}, onSkip: {})
}
