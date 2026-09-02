import SwiftUI

/// Чип-подсказка на главном экране: «Brainstorm ideas», «Create Image» и остальные.
///
/// Иконки в макете нарисованы обводкой светло-синим `#7495FF` — тем же,
/// каким набрана цена со скидкой на спецпредложении.
struct SuggestionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(AppFont.Icon.compact)
                    .foregroundStyle(AppColor.accentLight)
                    .frame(width: AppMetrics.sparkleSmall, height: AppMetrics.sparkleSmall)

                Text(title)
                    .appTextStyle(AppFont.captionMedium)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColor.bgElevated, in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(AppColor.strokePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
