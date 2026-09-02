import BroadUIFlows
import SwiftUI

/// Карточка тарифа: радиокнопка, название, цена и плашка выгоды.
///
/// Нажатие не должно давать затемнение, мерцание или системный press-effect —
/// это прямое требование платформы. `.plain` его не убирает, поэтому берём
/// `BroadNoPressEffectButtonStyle` из платформы: он отдаёт label как есть.
struct PlanRow: View {
    let plan: PaywallPlan
    let isSelected: Bool
    let onSelect: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.sm) {
                radio

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xxxs) {
                        if plan.showsSparkle {
                            SparkleShape()
                                .fill(AppColor.textPrimary)
                                .frame(width: AppMetrics.sparkleMedium, height: AppMetrics.sparkleMedium)
                        }

                        Text(plan.title)
                            .appTextStyle(AppFont.button)
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .appTextStyle(AppFont.captionMedium)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }

                Spacer(minLength: 12)

                Text(plan.price)
                    .appTextStyle(AppFont.price)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(Spacing.reg)
            .frame(minHeight: AppMetrics.planRow)
            .background(shape.fill(isSelected ? AppColor.accent.opacity(0.3) : AppColor.bgSecondary))
            .overlay(shape.strokeBorder(isSelected ? AppColor.accent : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) { badge }
        }
        .buttonStyle(BroadNoPressEffectButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var radio: some View {
        ZStack {
            if isSelected {
                Circle().fill(AppColor.accent)
                Circle().fill(AppColor.bgPrimary).frame(width: AppMetrics.radioDot, height: AppMetrics.radioDot)
            } else {
                Circle().strokeBorder(AppColor.textPrimary, lineWidth: 1.5)
            }
        }
        .frame(width: AppMetrics.controlSize, height: AppMetrics.controlSize)
    }

    @ViewBuilder
    private var badge: some View {
        if let text = plan.badge {
            Text(text)
                // В макете плашка набрана капителью (`SMALL_CAPS_FORCED`).
                .font(AppFont.captionMedium.font.smallCaps())
                .tracking(AppFont.captionMedium.tracking)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxxs)
                .background(AppColor.accent, in: .rect(cornerRadius: AppMetrics.badgeRadius))
                // В макете плашка сидит на верхней границе карточки, наполовину выходя за неё.
                .offset(x: -8, y: -AppMetrics.badgeRise)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xs) {
        PlanRow(plan: PreviewData.subscriptionPlans[0], isSelected: true, onSelect: {})
        PlanRow(plan: PreviewData.subscriptionPlans[1], isSelected: false, onSelect: {})
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
