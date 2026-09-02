import SwiftUI

/// Баннер поверх экрана, когда генерация готова, а пользователь в приложении.
///
/// По задумке дизайнера тап по баннеру ведёт к самой генерации; системный пуш
/// с тем же текстом уходит, только когда приложение свёрнуто.
struct InAppNotificationBanner: View {
    let title: String
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                AppMark(size: 38)

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(title)
                        .appTextStyle(AppFont.bannerTitle)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(message)
                        .appTextStyle(AppFont.bannerMessage)
                        .foregroundStyle(AppColor.textPrimary)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
            .padding(.leading, 14)
            .padding(.trailing, 17)
            .background(.regularMaterial, in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(AppColor.strokePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppMetrics.screenPadding)
        // Смахивание вверх убирает баннер — привычный жест для уведомлений.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -20 { onDismiss() }
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(title). \(message)"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack {
        InAppNotificationBanner(
            title: "The generations are ready!",
            message: "Check out the result now.",
            onTap: {}, onDismiss: {}
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
