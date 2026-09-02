import SwiftUI

@main
struct GeminiApp: App {
    @State private var compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
            AppFlowRootView(
                coordinator: compositionRoot.appFlowCoordinator,
                bootstrap: compositionRoot.bootstrap,
                onboardingViewModel: compositionRoot.onboardingViewModel,
                mainSceneDependencies: compositionRoot.mainSceneDependencies,
                paywallCatalog: compositionRoot.paywallCatalog
            )
            .preferredColorScheme(.dark)
            // Текст растёт вместе с системным размером, но не до предела:
            // макет свёрстан по фиксированной сетке и на accessibility5 разъезжается.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}
