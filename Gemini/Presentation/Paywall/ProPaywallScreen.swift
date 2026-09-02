import SwiftUI

/// Пейвол «Go Pro».
///
/// Крестик появляется не сразу, а через `AppConfiguration.paywallCloseDelay` —
/// так задумано дизайнером (заметка «Крестик появляется через 5 сек»).
///
/// Список тарифов приходит снаружи и рисуется **как есть**: платформа запрещает
/// фильтровать и переупорядочивать продукты, а вью обязан пережить и пустой список,
/// и один тариф, и повторяющиеся SKU.
struct ProPaywallScreen: View {
    let plans: [PaywallPlan]
    let bullets: [String]
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var allowsClose: Bool = true
    /// Каталог ещё грузится. Пока это так, отсчёт до крестика не начинается:
    /// иначе с любым сетевым каталогом список приезжает позже первого кадра,
    /// экран считает его пустым и показывает крестик сразу.
    var isLoadingCatalog: Bool = false

    /// Позиция выбранного продукта в списке. Именно позиция, а не SKU:
    /// Adapty может вернуть одинаковые идентификаторы, и тогда выбор по SKU
    /// подсветил бы сразу несколько карточек.
    @Binding var selectedIndex: Int?
    let onContinue: () -> Void
    let onClose: () -> Void
    let onRestore: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenTermsOfUse: () -> Void

    @State private var isCloseVisible = false

    /// Выбор считается настоящим, только если позиция действительно есть в списке.
    /// Adapty может вернуть пустой каталог, и тогда кнопка обязана быть неактивной.
    private var hasValidSelection: Bool {
        guard let selectedIndex else { return false }
        return plans.indices.contains(selectedIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Арт стоит в стеке, а не фоном: количество продуктов задаёт Adapty,
            // и при лишней карточке фоновая картинка оказывалась под контентом.
            // Свечение при этом на раскладку по-прежнему не влияет — оно внутри
            // `AccentGlow` построено на гибком `Color.clear`.
            TopArtwork(
                imageName: "PaywallCrown",
                glowSize: CGSize(width: 622, height: 453),
                glowCenterY: 235,
                imageTopPadding: 30,
                fitsAvailableSpace: true
            )
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        .overlay(alignment: .topLeading) { closeButton }
        // `initial: true` — это и есть предвыбор: без него экран открывается
        // без отмеченного тарифа и с мёртвой кнопкой «Continue». Дальше тот же
        // обработчик чинит выбор, если каталог перезагрузился и позиция от прежнего
        // списка указывает уже на другой продукт.
        .onChange(of: plans.count, initial: true) { _, count in
            guard let index = selectedIndex, index < count else {
                selectedIndex = plans.indices.first
                return
            }
        }
        .task(id: isLoadingCatalog) {
            guard allowsClose, !isCloseVisible, !isLoadingCatalog else { return }
            // Задержка крестика — свойство пейвола с продуктами. Если каталог
            // ответил и продуктов нет, запирать пользователя на пять секунд нельзя.
            guard !plans.isEmpty else {
                isCloseVisible = true
                return
            }
            // `try?` проглотил бы отмену и показал крестик так, будто задержка прошла.
            do {
                try await Task.sleep(for: AppConfiguration.paywallCloseDelay)
            } catch {
                return
            }
            withAnimation(.easeIn(duration: 0.2)) { isCloseVisible = true }
        }
    }

    private var bottomBlock: some View {
        VStack(spacing: Spacing.reg) {
            header
            plansList
            cancelNote
            actions
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, AppMetrics.screenPadding)
        .frame(maxWidth: .infinity)
        .bottomScrim(solidAt: 0.3)
    }

    private var header: some View {
        VStack(spacing: Spacing.xs) {
            Text("Go Pro")
                .appTextStyle(AppFont.h2)
                .foregroundStyle(AppColor.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(spacing: Spacing.xs) {
                        SparkleShape()
                            .fill(AppColor.textPrimary)
                            .frame(width: AppMetrics.sparkleSmall, height: AppMetrics.sparkleSmall)
                        Text(bullet)
                            .appTextStyle(AppFont.body)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var plansList: some View {
        // Пустой список — не ошибка вёрстки: Adapty может не вернуть ни одного продукта.
        // Тогда блок не показывается, а кнопка остаётся неактивной.
        if !plans.isEmpty {
            VStack(spacing: Spacing.xs) {
                ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                    PlanRow(plan: plan, isSelected: index == selectedIndex) {
                        selectedIndex = index
                    }
                    // Плашка выгоды выходит за верхнюю границу своей карточки.
                    // В макете она всегда на первой, и над ней пусто; у нас
                    // выгодным может оказаться любой тариф, поэтому карточке
                    // с плашкой добавляется место под выступ — иначе плашка
                    // ложится на карточку выше. Видимый зазор при этом
                    // остаётся макетным.
                    .padding(.top, index > 0 && plan.badge != nil ? AppMetrics.badgeRise : 0)
                }
            }
        }
    }

    private var cancelNote: some View {
        // Стрелка по часовой с открытым наконечником — как в макете.
        // `arrow.trianglehead.counterclockwise` рисует залитый треугольник
        // и крутится в другую сторону.
        Label("Cancel anytime", systemImage: "arrow.clockwise")
            .appTextStyle(AppFont.caption)
            // `#B9BABA`, как в макете — и здесь, и на спецпредложении: раньше
            // один и тот же элемент был покрашен на двух экранах по-разному.
            .foregroundStyle(AppColor.textMuted)
    }

    private var actions: some View {
        VStack(spacing: Spacing.xs) {
            PrimaryButton(
                title: String(localized: "Continue"),
                isInFlight: isPurchasing,
                isEnabled: hasValidSelection,
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

    @ViewBuilder
    private var closeButton: some View {
        if allowsClose, isCloseVisible {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(AppFont.Icon.medium)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget)
                    .background(AppColor.bgSecondary, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(.leading, AppMetrics.screenPadding)
            // Тот же отступ от статус-бара, что и у шапки остальных экранов.
            .padding(.top, Spacing.reg)
            .transition(.opacity)
        }
    }
}

#Preview {
    @Previewable @State var selected: Int? = 0

    ProPaywallScreen(
        plans: PreviewData.subscriptionPlans,
        bullets: ["Smart actions enabled", "Image generation", "Always ready to work"],
        selectedIndex: $selected,
        onContinue: {}, onClose: {}, onRestore: {},
        onOpenPrivacyPolicy: {}, onOpenTermsOfUse: {}
    )
}
