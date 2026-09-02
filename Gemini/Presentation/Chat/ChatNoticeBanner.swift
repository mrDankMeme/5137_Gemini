import SwiftUI

/// Баннер над полем ввода: кончились токены или исчерпан дневной лимит.
///
/// Оба состояния в макете выглядят одинаково и отличаются только текстом
/// и надписью на кнопке, поэтому это одна вью с двумя наборами строк.
struct ChatNoticeBanner: View {
    enum Kind: Equatable {
        case tokensExhausted
        case dailyLimitReached

        var title: String {
            switch self {
            case .tokensExhausted: String(localized: "Token limit reached")
            case .dailyLimitReached: String(localized: "Daily limit reached")
            }
        }

        var message: String {
            switch self {
            case .tokensExhausted:
                String(localized: "You've used all your tokens.\nPurchase more tokens to continue.")
            case .dailyLimitReached:
                String(localized: "Upgrade to the Pro plan or wait 24 hours for the limit to reset.")
            }
        }

        var actionTitle: String {
            switch self {
            case .tokensExhausted: String(localized: "Get Tokens")
            case .dailyLimitReached: String(localized: "Upgrade")
            }
        }
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xxs) {
            VStack(alignment: .leading, spacing: 0) {
                Text(kind.title)
                    .appTextStyle(AppFont.noticeTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text(kind.message)
                    .appTextStyle(AppFont.noticeMessage)
                    .foregroundStyle(AppColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                Text(kind.actionTitle)
                    .appTextStyle(AppFont.button)
                    .foregroundStyle(AppColor.onNoticeAccent)
                    .padding(.horizontal, Spacing.reg)
                    .frame(minHeight: AppMetrics.menuRow)
                    .background(AppColor.noticeAccent, in: .rect(cornerRadius: AppMetrics.badgeRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.sm)
        .background(AppColor.noticeBackground, in: .rect(cornerRadius: AppMetrics.badgeRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.badgeRadius, style: .continuous)
                .strokeBorder(AppColor.noticeAccent, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        ChatNoticeBanner(kind: .tokensExhausted) {}
        ChatNoticeBanner(kind: .dailyLimitReached) {}
    }
    .padding(AppMetrics.screenPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
