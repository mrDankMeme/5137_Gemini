import BroadMonetization
import BroadUIFlows
import SwiftUI

/// Корневой экран: показывает то, что решил координатор маршрута.
///
/// Маршрут задан платформой и приложением не меняется:
/// запуск → onboarding → стартовый пейвол → **новая** проверка доступа → главный экран.
struct AppFlowRootView: View {
    @ObservedObject var coordinator: AppFlowCoordinator
    let bootstrap: AppBootstrap
    let onboardingViewModel: OnboardingViewModel
    let mainSceneDependencies: MainSceneDependencies
    let paywallCatalog: PaywallCatalog

    /// Выбор берётся из полученного списка самим экраном пейвола, а не задаётся
    /// числом: при пустом каталоге фиктивная позиция включила бы кнопку покупки.
    @State private var selectedPlanIndex: Int?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var actionFailure: String?
    /// Политика и условия открываются внутри приложения: выбрасывать человека
    /// из онбординга или пейвола в Safari нельзя — обратно он может не вернуться.
    @State private var policyLink: URL?
    @Environment(\.openURL) private var openURL

    /// В Debug экран можно открыть напрямую аргументом запуска `-route`.
    private var route: AppFlowRoute {
        #if DEBUG
            DebugRouteOverride.route ?? coordinator.route
        #else
            coordinator.route
        #endif
    }

    var body: some View {
        Group {
            // Маршрут открывается только когда запуск завершился. `degraded` тоже
            // годится: часть необязательных шагов не удалась, но пользоваться можно.
            if !bootstrap.isReady {
                SplashView(failure: bootstrap.failure) {
                    Task { await bootstrap.retry() }
                }
            } else {
                routeContent
            }
        }
        .motionAwareAnimation(.easeInOut(duration: 0.25), value: route)
        .failureAlert($actionFailure)
        .policyLinkSheet(url: $policyLink)
        .task { await bootstrap.start() }
        .task { await paywallCatalog.load() }
    }

    @ViewBuilder
    private var routeContent: some View {
        Group {
            switch route {
            case .launch:
                SplashView()

            case .onboarding:
                OnboardingScreen(
                    viewModel: onboardingViewModel,
                    onFinished: coordinator.onboardingCompleted,
                    onOpenLink: open,
                    // Маршрут отсюда не двигаем: онбординг заканчивается сам,
                    // а доступ после него проверяется заново.
                    onRestore: { Task { await restore() } }
                )

            case .initialPaywall:
                ProPaywallScreen(
                    plans: paywallCatalog.subscriptionPlans,
                    bullets: [
                        String(localized: "Smart actions enabled"),
                        String(localized: "Image generation"),
                        String(localized: "Always ready to work")
                    ],
                    isPurchasing: isPurchasing,
                    isRestoring: isRestoring,
                    allowsClose: AppConfiguration.appFlowConfiguration.allowsInitialPaywallClose,
                    isLoadingCatalog: !paywallCatalog.isLoaded,
                    selectedIndex: $selectedPlanIndex,
                    onContinue: { Task { await purchase() } },
                    onClose: coordinator.initialPaywallDismissed,
                    onRestore: {
                        Task {
                            if await restore() { coordinator.initialPaywallDismissed() }
                        }
                    },
                    onOpenPrivacyPolicy: { open(.privacyPolicy) },
                    onOpenTermsOfUse: { open(.termsOfUse) }
                )

            case .main:
                MainScene(dependencies: mainSceneDependencies, paywallCatalog: paywallCatalog)
            }
        }
        .onAppear { coordinator.startIfNeeded() }
    }

    // MARK: Покупки

    /// Покупка со стартового пейвола.
    ///
    /// Успех не открывает premium сам: экран закрывается тем же
    /// `initialPaywallDismissed`, после которого координатор заново проверяет
    /// доступ, — как того требует платформа.
    ///
    /// Бэку покупка уходит не отсюда: `MainSceneModel` синкает подписку на
    /// каждом холодном старте, идемпотентно, и главный экран открывается сразу
    /// следом. Своего синка здесь нет ещё и потому, что идентификатор аккаунта
    /// до главного экрана не загружен.
    private func purchase() async {
        guard let index = selectedPlanIndex, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        guard let attempt = await paywallCatalog.purchaseSubscription(at: index) else { return }
        switch attempt.outcome {
        case .activated, .completed, .completedButUnverified:
            coordinator.initialPaywallDismissed()
        case .cancelled, .pending:
            // Отмена и ожидание подтверждения (Ask to Buy, семейный доступ)
            // не ошибки: экран просто остаётся открытым.
            break
        case let .failed(error):
            actionFailure = error.userMessage
        }
    }

    /// `true` — покупки нашлись и восстановлены.
    @discardableResult
    private func restore() async -> Bool {
        guard !isRestoring else { return false }
        isRestoring = true
        defer { isRestoring = false }

        switch await paywallCatalog.restore() {
        case .restored:
            return true
        case .nothingFound:
            actionFailure = String(localized: "No purchases to restore.")
            return false
        case let .unavailable(error), let .failed(error):
            actionFailure = error.userMessage
            return false
        }
    }

    private func open(_ destination: OnboardingFooterDestination) {
        switch destination {
        case .privacyPolicy:
            policyLink = DevelopmentConfiguration.privacyPolicyURL
        case .termsOfUse:
            policyLink = DevelopmentConfiguration.termsOfUseURL
        case .restorePurchases:
            // Восстановление — не ссылка: у экрана для него отдельный колбэк.
            break
        }
    }
}
