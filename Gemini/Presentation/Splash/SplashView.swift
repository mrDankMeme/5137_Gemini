import BroadCore
import SwiftUI

/// Первый экран запуска: знак Gemini на чёрном, пока идут шаги запуска.
///
/// Здесь **нельзя** запрашивать ATT — платформа запрещает трогать его в loader.
/// Запрос уходит только после появления первого слайда онбординга.
///
/// Если критический шаг запуска не удался, экран честно показывает это и даёт
/// повтор: молча висеть на логотипе нельзя.
struct SplashView: View {
    var failure: AppError?
    var onRetry: () -> Void = {}

    var body: some View {
        ZStack {
            AppColor.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                AppMark(size: 140)

                if failure != nil {
                    failureBlock
                }
            }
        }
        // Знак центрируется по всему экрану, как в макете (центр 437 = 874/2),
        // а не по безопасной области: та смещена статус-баром вниз на 13 pt.
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var failureBlock: some View {
        if let failure {
            VStack(spacing: Spacing.reg) {
                // Текст берём у платформы: она уже привела ошибку к виду,
                // который можно показать пользователю, без кодов и raw-описаний.
                Text(failure.userMessage)
                    .appTextStyle(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                if failure.isRetryable {
                    PrimaryButton(title: String(localized: "Retry"), action: onRetry)
                        .frame(maxWidth: AppMetrics.retryMaxWidth)
                }
            }
            .padding(.horizontal, AppMetrics.screenPadding)
        }
    }
}

#Preview("Запуск") {
    SplashView()
}

#Preview("Ошибка запуска") {
    SplashView(
        failure: AppError(
            kind: .offline,
            userMessage: "Check your connection and try again",
            diagnosticCode: "preview.offline",
            isRetryable: true
        ),
        onRetry: {}
    )
}
