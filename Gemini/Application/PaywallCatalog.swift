import BroadMonetization
import Foundation

/// Продукты пейволов и сама покупка/восстановление — единая точка входа
/// в `BroadMonetization` для основной сцены.
///
/// Каталог грузится **один раз** на запуск. Раньше стартовый пейвол и основная
/// сцена грузили его независимо. С Adapty это два вызова `LoadPaywallUseCase`,
/// два идентификатора показа и, как следствие, задвоенные impressions —
/// то есть испорченная атрибуция A/B-теста.
@Observable
@MainActor
final class PaywallCatalog {
    private(set) var subscriptionPlans: [PaywallPlan] = []
    private(set) var tokenPackages: [PaywallPlan] = []
    /// `nil` — показывать нечего: продукта нет либо скидка не выходит.
    private(set) var specialOffer: SpecialOffer?
    /// Цена самой дешёвой генерации в кредитах. Её знает только каталог
    /// моделей, а он грузится своим запросом и приходит обычно позже пейвола.
    private var creditsPerGeneration: Int?
    /// Каталог уже отвечал. Пустой список до ответа и пустой после — разные вещи:
    /// в первом случае экран ещё грузится, во втором продуктов действительно нет.
    private(set) var isLoaded = false

    /// Витрина, о показе которой сообщаем. Свой тип, а не `PaywallKind` экрана:
    /// слой приложения не должен знать про перечисления вью.
    enum Surface {
        case subscription
        case tokens
        case specialOffer
    }

    private let trackPaywallEvent: any TrackPaywallEventUseCaseProtocol
    private let loadPaywall: any LoadPaywallUseCaseProtocol
    private let selectProductUseCase: any SelectProductUseCaseProtocol
    private let purchaseProductUseCase: any PurchaseSelectedProductUseCaseProtocol
    private let restorePurchasesUseCase: any RestorePurchasesUseCaseProtocol
    private let entitlementStatusProvider: any EntitlementStatusProviderProtocol
    /// Нужен отдельно от провайдера статуса: у статуса нет срока, а экран
    /// «Current plan» обязан показывать настоящую дату, а не подставную.
    private let entitlementRepository: (any EntitlementRepositoryProtocol)?
    private let syncSubscriptionUseCase: SyncSubscriptionUseCase
    private let purchaseTokensSyncUseCase: PurchaseTokensSyncUseCase

    /// Сырые пейлоды нужны отдельно от `PaywallPlan`: `selectProduct` требует
    /// весь `PaywallPayload`, а вью получает только его проекцию для рисования.
    private var subscriptionPayload: PaywallPayload?
    private var tokenPayload: PaywallPayload?
    private var specialOfferPayload: PaywallPayload?
    private var specialOfferProduct: MonetizationProduct?
    /// Настройки кампании из remote config пейвола: включена ли она, на сколько
    /// открывается окно и чем зачеркнуть цену.
    private(set) var specialOfferRemote: SpecialOfferRemoteConfiguration?
    private var loadTask: Task<Void, Never>?

    /// Показ пейвола обязан уходить в Adapty: без него у варианта A/B-теста
    /// не будет просмотров, и конверсию посчитать не из чего — покупки есть,
    /// показов ноль. `logShowPaywall` платформа зовёт сама, изнутри этого
    /// события; нам остаётся сказать, что экран появился.
    func didAppear(_ surface: Surface) async {
        guard let payload = payload(for: surface) else { return }
        await trackPaywallEvent(.paywallShown(PaywallAnalyticsContext(paywall: payload)))
    }

    func didClose(_ surface: Surface) async {
        guard let payload = payload(for: surface) else { return }
        await trackPaywallEvent(
            .paywallClosed(PaywallAnalyticsContext(paywall: payload), reason: .dismissed)
        )
    }

    private func payload(for surface: Surface) -> PaywallPayload? {
        switch surface {
        case .subscription: subscriptionPayload
        case .tokens: tokenPayload
        case .specialOffer: specialOfferPayload
        }
    }

    /// Пакеты токенов подписаны тем, сколько это генераций, а цену генерации
    /// называет каталог моделей. Пришла она позже — пересобираем подписи,
    /// иначе они останутся пустыми до следующего открытия пейвола.
    func updateGenerationPrice(_ credits: Int?) {
        guard credits != creditsPerGeneration else { return }
        creditsPerGeneration = credits
        guard let tokenPayload else { return }
        tokenPackages = PaywallPlanFactory.plans(
            for: tokenPayload.products,
            showsSparkle: true,
            creditsPerGeneration: credits
        )
    }

    init(
        loadPaywall: any LoadPaywallUseCaseProtocol,
        selectProduct: any SelectProductUseCaseProtocol,
        purchaseProduct: any PurchaseSelectedProductUseCaseProtocol,
        restorePurchases: any RestorePurchasesUseCaseProtocol,
        entitlementStatusProvider: any EntitlementStatusProviderProtocol,
        entitlementRepository: (any EntitlementRepositoryProtocol)?,
        syncSubscription: SyncSubscriptionUseCase,
        syncTokenPurchase: PurchaseTokensSyncUseCase,
        trackPaywallEvent: any TrackPaywallEventUseCaseProtocol
    ) {
        self.trackPaywallEvent = trackPaywallEvent
        self.loadPaywall = loadPaywall
        selectProductUseCase = selectProduct
        purchaseProductUseCase = purchaseProduct
        restorePurchasesUseCase = restorePurchases
        self.entitlementStatusProvider = entitlementStatusProvider
        self.entitlementRepository = entitlementRepository
        syncSubscriptionUseCase = syncSubscription
        purchaseTokensSyncUseCase = syncTokenPurchase
    }

    /// Есть ли активная подписка прямо сейчас. Платформа не даёт живого потока
    /// событий на entitlement — только `async`-опрос, вызывать при открытии
    /// главного экрана и после покупки/восстановления.
    func currentEntitlementStatus() async -> EntitlementStatus {
        await entitlementStatusProvider.currentStatus()
    }

    /// Что показывать на экране «Current plan»: активна ли подписка и до какого
    /// числа. Дату выдумывать нельзя — если её нет, возвращаем `nil` и строка
    /// со сроком просто не рисуется.
    func currentSubscription() async -> (isActive: Bool, expiresAt: Date?, isLifetime: Bool) {
        guard let entitlementRepository else {
            return (await currentEntitlementStatus() == .active, nil, false)
        }
        let snapshot = await entitlementRepository.refreshEntitlement()
        return (snapshot.state == .active, snapshot.expirationDate, snapshot.isLifetime)
    }

    /// Повторные вызовы присоединяются к уже идущей загрузке, а не начинают новую.
    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task { [loadPaywall] in
            async let subscriptionOutcome = loadPaywall(PaywallLoadRequest(placementID: .main))
            async let tokenOutcome = loadPaywall(PaywallLoadRequest(placementID: .tokens))
            async let offerOutcome = loadPaywall(
                PaywallLoadRequest(placementID: PlacementID(rawValue: AppConfiguration.Placement.specialOffer))
            )
            let (subscription, tokens, offer) = await (subscriptionOutcome, tokenOutcome, offerOutcome)

            await MainActor.run {
                if case let .loaded(payload) = subscription {
                    self.subscriptionPayload = payload
                    self.subscriptionPlans = PaywallPlanFactory.plans(for: payload.products)
                }
                if case let .loaded(payload) = tokens {
                    self.tokenPayload = payload
                    self.tokenPackages = PaywallPlanFactory.plans(
                        for: payload.products,
                        showsSparkle: true,
                        creditsPerGeneration: self.creditsPerGeneration
                    )
                }
                if case let .loaded(payload) = offer, let product = payload.products.first {
                    self.specialOfferPayload = payload
                    self.specialOfferProduct = product
                    self.specialOfferRemote = payload.remoteConfiguration.specialOffer
                }
                // Кампанию продакт может включить и на основном пейволе —
                // у 232 гейт лежит именно там.
                if self.specialOfferRemote == nil, case let .loaded(payload) = subscription {
                    self.specialOfferRemote = payload.remoteConfiguration.specialOffer
                }
                self.isLoaded = true
            }
        }
        loadTask = task
        await task.value
        await buildSpecialOffer()
    }

    /// Собирается отдельным шагом, потому что зачёркнутую цену иногда
    /// приходится спрашивать у App Store — это сетевой вызов.
    private func buildSpecialOffer() async {
        guard let product = specialOfferProduct else {
            return
        }

        // Сначала среди тех тарифов, что уже пришли из Adapty: обычный недельный
        // может лежать и рядом со скидочным, и на основном пейволе.
        var candidates = ((specialOfferPayload?.products ?? []) + (subscriptionPayload?.products ?? []))
            .compactMap(PaywallPlanFactory.baseline(from:))

        if PaywallPlanFactory.specialOffer(for: product, comparedTo: candidates, remote: specialOfferRemote) == nil {
            // Не нашлось — спрашиваем цену прямо у App Store. Это не хардкод:
            // StoreKit отдаёт цену для витрины конкретного пользователя, а
            // подставить «$9.99» из головы значило бы соврать всем, у кого
            // недельный стоит иначе.
            candidates += await StoreKitPriceProvider
                .prices(for: DevelopmentConfiguration.subscriptionProductIDs)
                .compactMap(Self.baseline(from:))
        }

        specialOffer = PaywallPlanFactory.specialOffer(
            for: product,
            comparedTo: candidates,
            remote: specialOfferRemote
        )
    }

    /// Кампания включена продактом. Без явного `true` предложение не показываем:
    /// безопасное значение — выключено.
    var isSpecialOfferEnabled: Bool {
        specialOfferRemote?.isEnabled == true
    }

    private static func baseline(from price: StoreKitPriceProvider.Price) -> OfferBaseline? {
        let unit: OfferBaseline.Unit?
        switch price.periodUnit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        case .none: unit = nil
        @unknown default: unit = nil
        }
        guard let unit, let count = price.periodValue else {
            return nil
        }
        return OfferBaseline(
            id: price.productID,
            displayPrice: price.displayPrice,
            amount: price.amount,
            unit: unit,
            count: count
        )
    }

    struct PurchaseAttempt {
        let outcome: PurchaseOutcome
        let product: MonetizationProduct
    }

    /// `nil` значит «выбор невалиден» (пустой каталог, индекс вне диапазона) —
    /// экраны уже не дают такое нажать, но проверяем и здесь на случай гонки
    /// с перезагрузкой каталога.
    func purchaseSubscription(at index: Int) async -> PurchaseAttempt? {
        await purchase(index: index, payload: subscriptionPayload)
    }

    func purchaseTokenPackage(at index: Int) async -> PurchaseAttempt? {
        await purchase(index: index, payload: tokenPayload)
    }

    /// В плейсменте спецпредложения продукт один — выбирать не из чего.
    func purchaseSpecialOffer() async -> PurchaseAttempt? {
        await purchase(index: 0, payload: specialOfferPayload)
    }

    func restore() async -> RestoreOutcome {
        await restorePurchasesUseCase()
    }

    /// Репортит покупку бэку подписанной StoreKit-транзакцией — тот же паттерн,
    /// что у 232 (`BillingService`): бэк проверяет подпись Apple сам, поэтому
    /// это работает одинаково и в sandbox, и в проде, без отдельного Debug-пути.
    /// `false` — синк не прошёл (нет сети, нет ручки на бэке, транзакция ещё
    /// не видна StoreKit) — вызывающая сторона решает, что делать дальше.
    @discardableResult
    func syncSubscriptionPurchase(userID: String) async -> Bool {
        guard let jws = await StoreKitTransactionProvider.latestSubscriptionJWS(
            productIDs: DevelopmentConfiguration.subscriptionProductIDs
        ) else {
            return false
        }
        return (try? await syncSubscriptionUseCase(userID: userID, transactionJWS: jws)) != nil
    }

    @discardableResult
    func syncTokenPurchase(_ product: MonetizationProduct, userID: String) async -> Bool {
        guard let jws = await StoreKitTransactionProvider.latestJWS(for: product.productID.rawValue) else {
            return false
        }
        return (try? await purchaseTokensSyncUseCase(userID: userID, transactionJWS: jws)) != nil
    }

    private func purchase(index: Int, payload: PaywallPayload?) async -> PurchaseAttempt? {
        guard let payload, payload.products.indices.contains(index) else {
            return nil
        }
        let product = payload.products[index]
        guard let selection = selectProductUseCase(productPresentationID: product.id, in: payload) else {
            return nil
        }
        let outcome = await purchaseProductUseCase(selection, using: .apple)
        return PurchaseAttempt(outcome: outcome, product: product)
    }
}
