import BroadCore
import BroadMonetization
import BroadUIFlows
import Foundation
import Swinject

/// Единственное место, где собираются зависимости приложения.
///
/// Платформа требует порядок `BroadCore → BroadMonetization → BroadUIFlows`.
@MainActor
final class AppCompositionRoot {
    let appFlowCoordinator: AppFlowCoordinator
    let onboardingViewModel: OnboardingViewModel
    /// Сценарии основной части приложения. Здесь — единственное место, где
    /// известно, какие именно репозитории стоят за протоколами домена.
    let mainSceneDependencies: MainSceneDependencies
    /// Запуск приложения. Шаги выполняет движок платформы, а не `onAppear` вью.
    let bootstrap: AppBootstrap
    /// Каталог продуктов и сама покупка/восстановление — один на запуск,
    /// чтобы показы пейвола не задваивались.
    let paywallCatalog: PaywallCatalog

    private let assembler: Assembler

    init() {
        let logger = OSLogBroadLogger(subsystem: "com.ras.5137g4m769")
        let stateStore = UserDefaultsKeyValueStore(namespace: AppConfiguration.loggingSubsystem)

        // Настоящий системный запрос ATT. Когда его показать, решает не приложение,
        // а `OnboardingViewModel` по политике `afterFirstSlide`: в loader он невозможен.
        // Единственное место, где известны конкретные реализации репозиториев.
        let client = APIClient(
            baseURL: AppConfiguration.apiBaseURL,
            service: AppConfiguration.loggingSubsystem
        )
        let accountRepository = NetworkAccountRepository(client: client)

        // Сборка модулей платформы в предписанном порядке: Core → Monetization → UIFlows.
        // `MonetizationAssemblyFactory` собирает Adapty-кирпичи пакета в одну сборку —
        // деталь в её собственном комментарии.
        guard let monetization = MonetizationAssemblyFactory.make(
            accountRepository: accountRepository,
            cacheRepository: VersionedJSONCacheRepository(keyValueStore: stateStore)
        ) else {
            preconditionFailure(
                "Adapty-ключ или access level в DevelopmentConfiguration невалидны"
            )
        }

        let assembler = Assembler([
            BroadCoreAssembly(
                bootstrapSteps: [monetization.activationStep],
                logger: logger
            ),
            monetization.assembly,
        ])
        self.assembler = assembler

        guard let bootstrapUseCase = assembler.resolver.resolve(RunAppBootstrapUseCaseProtocol.self) else {
            preconditionFailure("BroadCoreAssembly не собран: нет RunAppBootstrapUseCase")
        }
        bootstrap = AppBootstrap(useCase: bootstrapUseCase)

        guard
            let entitlementStatusProvider = assembler.resolver.resolve((any EntitlementStatusProviderProtocol).self),
            let loadPaywall = assembler.resolver.resolve((any LoadPaywallUseCaseProtocol).self),
            let selectProduct = assembler.resolver.resolve((any SelectProductUseCaseProtocol).self),
            let purchaseProduct = assembler.resolver.resolve((any PurchaseSelectedProductUseCaseProtocol).self),
            let restorePurchases = assembler.resolver.resolve((any RestorePurchasesUseCaseProtocol).self),
            // Без него Adapty не узнает, что пейвол показали, и у варианта
            // A/B-теста не будет просмотров — конверсию считать не из чего.
            let trackPaywallEvent = assembler.resolver.resolve((any TrackPaywallEventUseCaseProtocol).self)
        else {
            preconditionFailure("BroadMonetizationAssembly не собран")
        }

        appFlowCoordinator = AppFlowCoordinator(
            // Крестик на стартовом пейволе есть, но появляется через 5 секунд —
            // задержкой управляет сам экран.
            configuration: AppConfiguration.appFlowConfiguration,
            progressRepository: KeyValueAppFlowProgressRepository(keyValueStore: stateStore),
            entitlementStatusProvider: entitlementStatusProvider
        )

        // Генерации живут на устройстве: серверной переписки у них нет.
        let archive = GenerationArchive()
        let chatRepository = ArchivedChatRepository(
            network: NetworkChatRepository(client: client),
            archive: archive
        )
        let libraryRepository = NetworkLibraryRepository(client: client)
        let catalogRepository = NetworkModelCatalogRepository(client: client)
        let mediaRepository = NetworkMediaGenerationRepository(client: client, archive: archive)

        mainSceneDependencies = MainSceneDependencies(
            sendMessage: SendMessageUseCase(repository: chatRepository),
            generateMedia: GenerateMediaUseCase(repository: mediaRepository),
            loadChats: LoadChatsUseCase(repository: chatRepository),
            loadMessages: LoadMessagesUseCase(repository: chatRepository),
            renameChat: RenameChatUseCase(repository: chatRepository),
            deleteChat: DeleteChatUseCase(repository: chatRepository),
            loadModels: LoadModelsUseCase(repository: catalogRepository),
            loadLibrary: LoadLibraryUseCase(repository: libraryRepository),
            saveGeneration: SaveGenerationUseCase(repository: libraryRepository),
            saveToPhotos: PhotoLibrarySaver(),
            deleteGeneration: DeleteGenerationUseCase(repository: libraryRepository),
            loadAccount: LoadAccountUseCase(repository: accountRepository),
            rateUsPolicy: RateUsPolicy(store: stateStore),
            specialOfferPolicy: SpecialOfferPolicy(store: stateStore),
            aiConsentPolicy: AIConsentPolicy(store: stateStore)
        )

        let billingSyncRepository = NetworkBillingSyncRepository(client: client)

        paywallCatalog = PaywallCatalog(
            loadPaywall: loadPaywall,
            selectProduct: selectProduct,
            purchaseProduct: purchaseProduct,
            restorePurchases: restorePurchases,
            entitlementStatusProvider: entitlementStatusProvider,
            // Необязательный: без него экран «Current plan» просто не покажет срок.
            entitlementRepository: assembler.resolver.resolve((any EntitlementRepositoryProtocol).self),
            syncSubscription: SyncSubscriptionUseCase(repository: billingSyncRepository),
            syncTokenPurchase: PurchaseTokensSyncUseCase(repository: billingSyncRepository),
            trackPaywallEvent: trackPaywallEvent
        )

        onboardingViewModel = OnboardingViewModel(
            configuration: AppConfiguration.onboardingConfiguration,
            requestTrackingAuthorizationUseCase: RequestTrackingAuthorizationUseCase(
                repository: SystemTrackingAuthorizationAdapter()
            )
        )
    }
}
