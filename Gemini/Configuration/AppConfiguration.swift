import BroadUIFlows
import Foundation

/// Настройки, специфичные для 5137 Gemini: тексты, правила Adapty и параметры маршрута.
///
/// Всё временное живёт в `DevelopmentConfiguration`; здесь только то,
/// что уже определено дизайном и правилами платформы.
enum AppConfiguration {
    static let loggingSubsystem = "com.ras.5137g4m769"

    /// Во сколько раз «старая» цена спецпредложения больше самой offer-цены.
    ///
    /// У offer-продукта своей старой цены не существует — это отдельный SKU
    /// со своей ценой, магазин не знает, от чего он уценён. Обычно её берут из
    /// такого же по периоду тарифа основного пейвола, но полагаться на это
    /// нельзя: пейвол за день менялся и недельного тарифа в нём не осталось,
    /// а вместе с ним пропала и зачёркнутая цена.
    ///
    /// Поэтому запасной вариант считаем сами. Множитель, а не сумма: цена
    /// получается в валюте витрины пользователя, а «$9.99» врало бы всем
    /// остальным. Значение из remote config, если задано, всё равно главнее.
    static let specialOfferCrossedPriceMultiplier: Decimal = 2

    /// Адрес backend 5137. Инстанс того же сервиса, что у 232 и 5142, — отдельная
    /// копия на приложение, различается только конфигурацией.
    static let apiBaseURL = URL(string: "https://devsupplyr.shop")!

    // MARK: Adapty

    /// Базовые placement из README платформы. У каждого есть резерв на логический `main`.
    enum Placement {
        static let onboarding = "onboarding"
        static let proIcon = "pro_icon"
        static let settings = "settings"
        static let main = "main"
        static let ctr = "CTR"
        static let specialOffer = "special_offer"
        /// Пейвол пакетов токенов.
        static let tokens = "tokens"
    }

    /// Ключи Remote Config пейвола `main`. Безопасное стартовое значение у всех — `false`.
    enum RemoteConfigKey {
        static let ruPay = "ru_pay"
        static let autoRevenueView = "auto_revenue_view"
        static let specialOffer = "special_offer"
    }

    // MARK: Маршрут запуска

    /// Конфигурация маршрута. Живёт здесь, чтобы стартовый пейвол и координатор
    /// читали одно и то же значение: иначе крестик может появиться на экране,
    /// который платформа закрывать не разрешает.
    /// `onceAfterOnboarding` — пейвол один раз сразу после онбординга, решение
    /// запоминается. Платформа 1.0.0 разделила прежний `enabled` на две политики;
    /// вторая, `everyColdLaunchWhileInactive`, показывает пейвол на каждом холодном
    /// запуске, пока нет подписки. Это продуктовое решение, а не техническое —
    /// пока сохраняем поведение, которое было.
    static let appFlowConfiguration = AppFlowConfiguration(
        onboarding: .enabled,
        initialPaywall: .onceAfterOnboarding(allowsClose: true)
    )

    // MARK: Пейвол

    /// Крестик появляется через 5 секунд — прямое указание дизайнера
    /// (заметка «Крестик появляется через 5 сек» в секции «onbording & paywall»).
    static let paywallCloseDelay: Duration = .seconds(5)

    // MARK: Онбординг

    /// Три слайда из Figma. Идентификатор медиа — имя ассета в `Assets.xcassets`.
    ///
    /// ATT запрашивается по политике `afterFirstSlide`: платформа запрещает трогать ATT
    /// в loader, запрос допустим только после появления первого слайда.
    /// Rate Us внутри онбординга не показывается — это тоже требование платформы.
    static let onboardingConfiguration = OnboardingConfiguration(
            pages: [
                OnboardingPageConfiguration(
                    id: "ask",
                    title: String(localized: "Ask AI Anything"),
                    subtitle: String(localized: "Get instant help with ideas, writing, coding, and everyday tasks"),
                    media: OnboardingMediaDescriptor(identifier: "OnboardingArt1")
                ),
                OnboardingPageConfiguration(
                    id: "create",
                    title: String(localized: "Bring Ideas to Life"),
                    subtitle: String(localized: "Create stunning images and videos in just a few taps"),
                    media: OnboardingMediaDescriptor(identifier: "OnboardingArt2")
                ),
                OnboardingPageConfiguration(
                    id: "organize",
                    title: String(localized: "Keep It All in One Place"),
                    subtitle: String(localized: "Access your chats, projects, and files whenever you need them"),
                    media: OnboardingMediaDescriptor(identifier: "OnboardingArt3")
                )
            ],
            continueTitle: String(localized: "Continue"),
            completionTitle: String(localized: "Continue"),
            progressAccessibilityLabel: String(localized: "Onboarding step"),
            footerLinks: [
                OnboardingFooterLinkConfiguration(
                    destination: .privacyPolicy,
                    title: String(localized: "Privacy Policy"),
                    accessibilityLabel: "Privacy Policy"
                ),
                OnboardingFooterLinkConfiguration(
                    destination: .termsOfUse,
                    title: String(localized: "Terms of Use"),
                    accessibilityLabel: "Terms of Use"
                )
            ],
        trackingAuthorizationPolicy: .afterFirstSlide()
    )
}
