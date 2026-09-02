import SwiftUI

/// Спецпредложение: скидка с обратным отсчётом и одним тарифом.
///
/// Экран полностью опционален — платформа считает отсутствие конфигурации
/// спецпредложения нормой, а не ошибкой, поэтому показывается он только когда
/// remote config действительно его включил.
struct SpecialOfferScreen: View {
    let discountTitle: String
    let planName: String
    let planPeriod: String
    let price: String
    let crossedPrice: String
    let endsAt: Date
    /// Экран закрывается сам, когда предложение истекло.
    var onExpire: () -> Void = {}
    var isPurchasing: Bool = false
    var isRestoring: Bool = false

    let onContinue: () -> Void
    let onClose: () -> Void
    let onRestore: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenTermsOfUse: () -> Void

    /// Пока не истекло — можно покупать. Истёкшее предложение продавать нельзя.
    @State private var isExpired = false

    var body: some View {
        VStack(spacing: 0) {
            headline
                .padding(.top, AppMetrics.specialOfferHeadlineTop)
            Spacer(minLength: 0)
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Отступ заголовка отмеряется от верха экрана, а не от безопасной зоны:
        // в макете это абсолютные 194 pt, и на разных вырезах иначе не сойдётся.
        .ignoresSafeArea(edges: .top)
        .background {
            Image("SpecialOfferArt")
                .resizable()
                .scaledToFill()
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .background(AppColor.bgPrimary)
        .overlay(alignment: .topLeading) {
            CircleIconButton(
                systemImage: "xmark",
                accessibilityLabel: "Close",
                glyph: AppFont.Icon.large,
                action: onClose
            )
            .padding(.leading, AppMetrics.screenPadding)
            // Тот же отступ от статус-бара, что и у шапки остальных экранов.
            .padding(.top, Spacing.reg)
        }
    }

    private var headline: some View {
        VStack(spacing: 48) {
            VStack(spacing: -12) {
                Text("Special Offer")
                    // В макете надпись набрана капителью.
                    .font(AppFont.offerEyebrow.smallCapsFont)
                    .foregroundStyle(AppColor.accentLight)
                    // Высота строки задаётся явно: `lineSpacing` — это зазор
                    // между строками, у одиночной он не работает вовсе, и блок
                    // недобирал 12 pt. Ровно на столько таймер уезжал вверх.
                    .frame(height: AppFont.offerEyebrow.lineHeight)

                // Процент называет продакт или считает каталог. Не назвал и
                // сравнивать не с чем — строки просто нет, пустая занимала бы
                // 94 pt пустоты под «Special Offer».
                if !discountTitle.isEmpty {
                    Text(discountTitle)
                        .appTextStyle(AppFont.offerDiscount)
                        .foregroundStyle(AppColor.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(height: AppFont.offerDiscount.lineHeight)
                }
            }

            OfferCountdown(endsAt: endsAt) {
                    isExpired = true
                    onExpire()
                }
                // В макете карточка отсчёта — 282 pt по центру, а не во всю ширину.
                .frame(width: AppMetrics.countdownWidth)
        }
        .padding(.horizontal, AppMetrics.screenPadding)
    }

    private var bottomBlock: some View {
        VStack(spacing: Spacing.reg) {
            planCard

            // Стрелка по часовой с открытым наконечником — как в макете.
            // `arrow.trianglehead.counterclockwise` рисует залитый треугольник
            // и крутится в другую сторону.
            Label("Cancel anytime", systemImage: "arrow.clockwise")
                .appTextStyle(AppFont.caption)
                .foregroundStyle(AppColor.textMuted)

            VStack(spacing: Spacing.xs) {
                PrimaryButton(
                    title: String(localized: "Continue"),
                    isInFlight: isPurchasing,
                    isEnabled: !isExpired,
                    action: onContinue
                )

                LegalFooter(
                    onPrivacyPolicy: onOpenPrivacyPolicy,
                    onRestore: onRestore,
                    onTermsOfUse: onOpenTermsOfUse,
                    isRestoring: isRestoring
                )
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, AppMetrics.screenPadding)
        .bottomScrim(solidAt: 0.3)
    }

    private var planCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(planName)
                    .appTextStyle(AppFont.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.textPrimary)

                Text(planPeriod)
                    .appTextStyle(AppFont.captionMedium)
                    .foregroundStyle(AppColor.textPrimary)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(price)
                    .appTextStyle(AppFont.offerPrice)
                    .foregroundStyle(AppColor.accentLight)

                // Зачёркнутой цены может не быть: у offer-продукта своей «старой»
                // цены не существует, а обычного тарифа того же периода в пейволе
                // может не оказаться. Тогда строки нет — так же в 232 и 6010.
                if !crossedPrice.isEmpty {
                    Text(crossedPrice)
                        .appTextStyle(AppFont.captionMedium)
                        .foregroundStyle(AppColor.textPrimary)
                        .strikethrough()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(AppColor.bgElevatedStrong, in: .rect(cornerRadius: AppMetrics.cardRadius))
        // В макете у карточки background blur 12 — она стеклянная и лежит
        // поверх фотографии. Плоской заливкой это не передать: сквозь неё
        // виден резкий фон, а не размытый.
        .background(.ultraThinMaterial, in: .rect(cornerRadius: AppMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                .strokeBorder(AppColor.strokeSecondary, lineWidth: 2)
        )
    }
}
//
//#Preview {
//    SpecialOfferScreen(
//        discountTitle: PreviewData.offerDiscount,
//        planName: PreviewData.offerPlanName,
//        planPeriod: PreviewData.offerPlanPeriod,
//        price: PreviewData.offerPrice,
//        crossedPrice: PreviewData.offerCrossedPrice,
//        endsAt: Date().addingTimeInterval(23 * 3600 + 59 * 60 + 42),
//        onContinue: {}, onClose: {}, onRestore: {},
//        onOpenPrivacyPolicy: {}, onOpenTermsOfUse: {}
//    )
//}
