import Foundation
import SwiftUI

/// Синяя кнопка справа в шапке.
///
/// В макете два состояния: у пользователя без подписки — надпись «Pro»,
/// у пользователя с токенами — их количество. Иконка-искра одна и та же.
/// `.pro` в макете третьим состоянием не нарисован — подписчик без токенов
/// показывается тем же «Pro», просто по правде, а не как апсейл-заглушка.
struct ProButton: View {
    enum Content: Equatable {
        case upgrade
        case tokenBalance(Decimal)
        case pro
    }

    let content: Content
    let action: () -> Void

    private var title: String {
        switch content {
        case .upgrade, .pro: "Pro"
        case let .tokenBalance(amount): amount.formatted(.number.precision(.fractionLength(0 ... 2)))
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxxs) {
                SparkleShape()
                    .fill(AppColor.textPrimary)
                    .frame(width: AppMetrics.sparkleSmall, height: AppMetrics.sparkleSmall)

                Text(title)
                    .appTextStyle(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(.leading, Spacing.sm)
            .padding(.trailing, Spacing.reg)
            .frame(height: AppMetrics.tapTarget)
            .background(AppColor.accent, in: .rect(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch content {
        case .upgrade: String(localized: "Get Pro")
        // Число форматируется до подстановки: `Decimal` в локализованной строке
        // подставляется отладочным описанием и не переводится по правилам языка.
        case .tokenBalance: String(localized: "\(title) tokens. Buy more")
        case .pro: String(localized: "Pro member")
        }
    }
}
