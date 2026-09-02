import BroadCore
import BroadMonetization
import Foundation

/// Собирает `BroadMonetizationAssembly` и шаг бутстрапа, который активирует Adapty.
///
/// Платформа не даёт готовой сборки под ключ — только кирпичи (`Documentation/PublicAPI.md`
/// пакета `broad-monetization-ios`), собирать их в одном месте и с одним `AdaptyRepositoryContext`
/// обязан хост-app: `AdaptyMonetizationFactory` и `AdaptySDKEntitlementProfileClient` должны
/// делить один и тот же `context`, иначе у них разные `sdkCompositionID` и активационный гейт
/// решит, что это две разные, конкурирующие сборки платформы.
enum MonetizationAssemblyFactory {
    struct Output {
        let assembly: BroadMonetizationAssembly
        let activationStep: BootstrapStep
    }

    static func make(
        accountRepository: any AccountRepositoryProtocol,
        cacheRepository: any CacheRepositoryProtocol
    ) -> Output? {
        let subject = EntitlementSubject.anonymous

        guard let platformConfiguration = AdaptyPlatformConfiguration(
            apiKey: DevelopmentConfiguration.adaptyPublicKey,
            accessLevelID: DevelopmentConfiguration.adaptyAccessLevel,
            subject: subject
        ) else {
            return nil
        }

        let identityProvider = AccountAdaptyIdentityProvider(accountRepository: accountRepository)
        // Общий на активацию, покупки и проверку entitlement — см. комментарий над enum.
        let context = AdaptyRepositoryContext()

        // Список плейсментов подтверждён аккаунт-менеджером 2026-08-28: onboarding,
        // chat, pro_icon, settings, special_offer, tokens. У платформы логический
        // `PlacementID.main` — это наш пейвол подписки, а в Adapty под него заведён
        // плейсмент с именем `chat`, а не `main`; `AdaptyPlacementRegistry.main`
        // ниже — это как раз тот параметр, куда он и уходит (это fallback-слот
        // реестра, не наше логическое имя). `CTR` в подтверждённый список не попал —
        // маппинг для него не завожу, чтобы не держать в коде неподтверждённую строку.
        let placementRegistry = AdaptyPlacementRegistry(
            main: AdaptyPlacementID(rawValue: "chat"),
            mappings: [
                .onboarding: AdaptyPlacementID(rawValue: PlacementID.onboarding.rawValue),
                .tokens: AdaptyPlacementID(rawValue: PlacementID.tokens.rawValue),
                .proIcon: AdaptyPlacementID(rawValue: PlacementID.proIcon.rawValue),
                .settings: AdaptyPlacementID(rawValue: PlacementID.settings.rawValue),
                PlacementID(rawValue: AppConfiguration.Placement.specialOffer):
                    AdaptyPlacementID(rawValue: AppConfiguration.Placement.specialOffer)
            ]
        )

        let messages = AdaptyMonetizationMessages(
            activationUnavailable: String(localized: "Store is unavailable right now. Try again later."),
            paywallUnavailable: String(localized: "Couldn't load offers. Check your connection and try again."),
            productUnavailable: String(localized: "This item is no longer available."),
            purchaseFailed: String(localized: "Purchase failed. Please try again."),
            restoreFailed: String(localized: "Couldn't restore purchases. Please try again.")
        )

        let factory = AdaptyMonetizationFactory(
            configuration: platformConfiguration,
            identityProvider: identityProvider,
            placementRegistry: placementRegistry,
            messages: messages,
            context: context
        )

        let premiumCatalog = ApplePremiumProductCatalog(
            entries: DevelopmentConfiguration.subscriptionProductIDs.map {
                .init(productID: $0, kind: .autoRenewable)
            }
        )
        let appleRegistration = AppleEntitlementSourceFactory().makeRegistration(
            configuration: AppleEntitlementSourceConfiguration(
                subject: subject,
                // Профиль Adapty может отставать от App Store на минуты — тут заведомо
                // короткий TTL с суточным офлайн-грейсом, чтобы разрыв связи не гасил Pro.
                freshnessPolicy: EntitlementFreshnessPolicy(
                    timeToLive: 3600,
                    offlineActiveGrace: 3 * 24 * 3600
                ),
                appBundleIdentifier: DevelopmentConfiguration.bundleIdentifier,
                productCatalog: premiumCatalog,
                ownershipPolicy: .appStoreAccount
            )
            // Верификатор Adapty сюда не добавляется, хотя соблазн есть.
            // `AppleEntitlementRepository` считает доступ отсутствующим только
            // если `.inactive` сказали ВСЕ верификаторы, а профиль Adapty SDK
            // намеренно остаётся `unqualified` («unqualified SDK cache map to
            // unresolved») — то есть этот верификатор не отвечает `.inactive`
            // никогда. С ним в списке `.inactive` недостижим, статус выходит
            // `.unknown`, и `AppFlowStateMachine` уводит с `.unknown` прямо в
            // `main`: стартовый пейвол не показывался вообще никому.
            // Подписку, купленную мимо этого устройства, приносит восстановление
            // и синк с бэком, а не этот верификатор.
        )

        let entitlementEngine = EntitlementEngine(
            registrations: [appleRegistration],
            subject: subject,
            cache: VersionedEntitlementCache(repository: cacheRepository),
            timeoutPolicy: .seconds(12)
        )

        let services = factory.makeServices(
            entitlementRepository: entitlementEngine,
            analytics: NoOpMonetizationAnalytics(),
            errors: MonetizationFlowErrors(
                stalePaywallLoad: AppError(
                    kind: .timeout,
                    userMessage: messages.paywallUnavailable,
                    diagnosticCode: "monetization.paywall.stale",
                    isRetryable: true
                ),
                purchaseInProgress: AppError(
                    kind: .unavailable,
                    userMessage: messages.purchaseFailed,
                    diagnosticCode: "monetization.purchase.in-progress",
                    isRetryable: false
                ),
                restoreVerificationUnavailable: AppError(
                    kind: .unavailable,
                    userMessage: messages.restoreFailed,
                    diagnosticCode: "monetization.restore.unavailable",
                    isRetryable: true
                )
            ),
            pendingApplePurchaseStore: PendingApplePurchaseStore(
                subject: subject,
                applicationIdentifier: DevelopmentConfiguration.bundleIdentifier,
                cache: cacheRepository
            ),
            pendingAppleTransactionRecovery: StoreKitPendingAppleTransactionRecovery(
                appBundleIdentifier: DevelopmentConfiguration.bundleIdentifier,
                ownershipPolicy: .appStoreAccount
            ),
            operationGate: MonetizationOperationGate()
        )

        let assembly = BroadMonetizationAssembly(entitlementEngine: entitlementEngine, services: services)

        let activationStep = BootstrapStep(
            id: BootstrapStepID(rawValue: "monetization.adapty-activate"),
            name: "Adapty activation",
            // Фоновый: сбой Adapty не должен запирать пользователя на splash — пейвол
            // просто придёт пустым (`ProPaywallScreen`/`TokenPaywallScreen` это переживают).
            criticality: .background,
            timeoutPolicy: .seconds(20),
            retryPolicy: .none
        ) {
            switch await services.activate() {
            case .activated: .completed
            case let .unavailable(error): .degraded(error)
            }
        }

        return Output(assembly: assembly, activationStep: activationStep)
    }
}
