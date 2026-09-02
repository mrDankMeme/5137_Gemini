import SwiftUI

/// Просьба оценить приложение изнутри настроек.
///
/// Отличается от полноэкранного `RateUsScreen`: тот показывается по ходу сценария,
/// а этот открывается по строке «Rate app». Системное окно оценки поднимается
/// только после согласия — навязывать его сразу нельзя.
///
/// В макете это **центрированный алерт**, а не нижняя шторка: карточка 370×390
/// со стеклянным фоном посреди экрана. Показывается слоем поверх сцены, а не
/// презентацией — тот же приём, что у меню: с презентации не поднять следующую,
/// а отсюда уходит системное окно оценки.
struct RateUsPopup: View {
    let onRate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Затемнение под карточкой: без него алерт висит в воздухе,
            // а нажатие мимо него ничего не закрывает.
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
        }
    }

    private var card: some View {
        VStack(spacing: AppMetrics.alertSpacing) {
            // Белая искра без подложки — в отличие от знака приложения,
            // у которого в макете светлый скруглённый квадрат.
            SparkleShape()
                .fill(AppColor.textPrimary)
                .frame(width: AppMetrics.popupMark, height: AppMetrics.popupMark)
                .accessibilityHidden(true)

            VStack(spacing: AppMetrics.alertSpacing) {
                // 17/22, как в макете: это стиль строки настроек, не заголовок экрана.
                Text("Loving your AI companion?")
                    .appTextStyle(AppFont.rowTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text("Take a moment to rate us. It means the world to our team!")
                    .appTextStyle(AppFont.row)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Spacing.reg)

            PrimaryButton(title: String(localized: "Rate us"), action: onRate)

            // Вторая кнопка того же размера, но с заливкой `#FFFFFF 10%`
            // и приглушённой подписью — не текстовая ссылка.
            Button(action: onDismiss) {
                Text("Not Now")
                    .appTextStyle(AppFont.button)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppMetrics.buttonHeight)
                    .background(AppColor.bgElevated, in: .rect(cornerRadius: AppMetrics.buttonRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(AppMetrics.screenPadding)
        .frame(width: AppMetrics.alertWidth)
        // Настоящее стекло на iOS 26, свой блюр под тем же видом до неё —
        // тот же приём, что у 232 (`adaptiveGlassEffect`), вместо плоского
        // `.ultraThinMaterial`, который на тёмном фоне выглядел тусклее
        // стекла из макета.
        .adaptiveGlassEffect(in: .rect(cornerRadius: AppMetrics.alertRadius))
    }
}

#Preview {
    ZStack {
        AppColor.bgPrimary
        RateUsPopup(onRate: {}, onDismiss: {})
    }
    .ignoresSafeArea()
}
