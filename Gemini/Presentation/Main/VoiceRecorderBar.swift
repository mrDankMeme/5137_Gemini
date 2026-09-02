import SwiftUI

/// Поле ввода во время диктовки: отмена, дорожка звука, время и подтверждение.
///
/// Два состояния из макета: идёт запись — показывается таймер, идёт распознавание —
/// вместо таймера надпись «Transcribing...», а подтверждение блокируется.
struct VoiceRecorderBar: View {
    /// Уровни громкости для дорожки, от 0 до 1.
    let levels: [CGFloat]
    let duration: Duration
    let isTranscribing: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            CircleIconButton(
                systemImage: "xmark",
                accessibilityLabel: "Cancel recording",
                size: 36,
                background: nil,
                action: onCancel
            )

            HStack(spacing: Spacing.xxs) {
                waveform

                // Через тернарник это был `Text(String)` — вторая ветка отдаёт
                // готовую строку из `.formatted`, тип выводился в `String`,
                // и надпись не переводилась.
                Text(isTranscribing
                     ? String(localized: "Transcribing...")
                     : duration.formatted(.time(pattern: .minuteSecond)))
                    // 16/22.4, как в макете: это стиль поля ввода, а не `body`.
                    .appTextStyle(AppFont.input)
                    .foregroundStyle(AppColor.textTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            CircleIconButton(
                systemImage: "checkmark",
                accessibilityLabel: "Done",
                size: 36,
                background: AppColor.accent,
                isEnabled: !isTranscribing,
                action: onConfirm
            )
        }
        .padding(Spacing.xs)
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
        )
    }

    /// Дорожка звука. Пока распознаётся речь, она замирает и гаснет — чтобы было
    /// видно, что запись уже закончилась.
    ///
    /// Рисуется `Canvas`, а не стеком капсул: у стека из 44 полосок фиксированной
    /// ширины собственная ширина 174 pt, которую нельзя сжать. С длинной надписью
    /// «Transcribing…» поле ввода становилось шире экрана и растягивало весь экран,
    /// сдвигая шапку и чипы за края. У `Canvas` собственной ширины нет.
    private var waveform: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 2
            let gap: CGFloat = 2
            let step = barWidth + gap
            let visible = min(levels.count, max(0, Int(size.width / step)))

            for index in 0 ..< visible {
                let height = max(3, levels[index] * 28.5)
                let rect = CGRect(
                    x: CGFloat(index) * step,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2),
                             with: .color(AppColor.textSecondary))
            }
        }
        .frame(height: AppMetrics.waveformHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isTranscribing ? 0.35 : 1)
        .accessibilityHidden(true)
    }
}

#Preview {
    let levels = (0 ..< 40).map { _ in CGFloat.random(in: 0.2 ... 1) }

    return VStack(spacing: Spacing.sm) {
        VoiceRecorderBar(levels: levels, duration: .seconds(12), isTranscribing: false,
                         onCancel: {}, onConfirm: {})
        VoiceRecorderBar(levels: levels, duration: .seconds(12), isTranscribing: true,
                         onCancel: {}, onConfirm: {})
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
