import SwiftUI

/// Главная кнопка макета: капсула 54 pt, фон `Accent/primary`, текст btntxt.
///
/// Пока идёт работа с backend или SDK, кнопка показывает индикатор и не нажимается
/// повторно. Платформа требует, чтобы `isInFlight` выставлялся синхронно — **до**
/// создания `Task` и первого `await`, — поэтому состояние приходит снаружи,
/// а кнопка только отражает его.
struct PrimaryButton: View {
    /// `String`, а не `LocalizedStringKey`: сюда приходит и литерал, и уже
    /// локализованная подпись из конфигурации онбординга.
    let title: String
    var isInFlight: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .appTextStyle(AppFont.button)
                    .opacity(isInFlight ? 0 : 1)

                if isInFlight {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppColor.textPrimary)
                }
            }
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.buttonHeight)
            .background(AppColor.accent, in: .rect(cornerRadius: AppMetrics.buttonRadius))
        }
        .buttonStyle(.plain)
        .disabled(isInFlight || !isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isInFlight ? Text("In progress") : Text(""))
    }
}

#Preview {
    VStack(spacing: Spacing.reg) {
        PrimaryButton(title: "Continue") {}
        PrimaryButton(title: "Continue", isInFlight: true) {}
        PrimaryButton(title: "Continue", isEnabled: false) {}
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
