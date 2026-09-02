import SwiftUI

/// Таймер спецпредложения: «OFFER ENDS IN» и оставшиеся часы, минуты, секунды.
///
/// Тикает от переданного момента окончания. Когда время вышло, отдаёт нули,
/// а решение, что делать дальше, принимает экран — платформа считает
/// отсутствие или истечение спецпредложения нормальной ситуацией, а не ошибкой.
struct OfferCountdown: View {
    let endsAt: Date
    /// Вызывается, когда время вышло: истёкшее предложение продавать нельзя.
    var onExpire: () -> Void = {}

    @State private var remaining: TimeInterval = 0

    /// Оставшееся время, разложенное по разрядам таймера.
    private struct Remaining {
        let hours: Int
        let minutes: Int
        let seconds: Int

        init(_ interval: TimeInterval) {
            let total = max(0, Int(interval))
            hours = total / 3600
            minutes = (total % 3600) / 60
            seconds = total % 60
        }
    }

    private var parts: Remaining { Remaining(remaining) }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("OFFER ENDS IN")
                .appTextStyle(AppFont.countdownCaption)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, Spacing.reg)
                .padding(.vertical, Spacing.xxs)
                .background(
                    AppColor.accent,
                    in: .rect(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                )

            HStack(spacing: Spacing.xs) {
                unit(parts.hours, caption: "HRS")
                separator
                unit(parts.minutes, caption: "MIN")
                separator
                unit(parts.seconds, caption: "SEC")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .background(AppColor.strokePrimary, in: .rect(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
        )
        .task(id: endsAt) { await tick() }
        .accessibilityElement()
        .accessibilityLabel("Offer ends in \(parts.hours) hours \(parts.minutes) minutes")
    }

    private func unit(_ value: Int, caption: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", value))
                .appTextStyle(AppFont.countdownValue)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()

            Text(caption)
                .appTextStyle(AppFont.countdownCaption)
                .foregroundStyle(AppColor.textTertiary)
        }
        .frame(width: AppMetrics.countdownUnitWidth)
    }

    private var separator: some View {
        Text(verbatim: ":")
            .appTextStyle(AppFont.countdownValue)
            .foregroundStyle(AppColor.textPrimary)
            .accessibilityHidden(true)
    }

    private func tick() async {
        remaining = endsAt.timeIntervalSinceNow
        // Секундный шаг вместо `Timer`: задача сама умирает вместе с экраном,
        // так что таймер не переживает закрытие пейвола.
        while !Task.isCancelled, remaining > 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            remaining = endsAt.timeIntervalSinceNow
        }

        guard !Task.isCancelled else { return }
        onExpire()
    }
}
