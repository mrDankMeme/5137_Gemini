import Foundation

/// ⚠️ ЧАСТЬ ЗНАЧЕНИЙ ВСЁ ЕЩЁ ВРЕМЕННАЯ — ЗАМЕНИТЬ ПЕРЕД РЕЛИЗОМ.
///
/// Аккаунт-менеджер выдал 2026-08-28 данные аккаунта Fenuko Flow (bundle,
/// team ID, Adapty-ключ, юридические ссылки, ссылка на App Store) — они ниже
/// уже настоящие. Цены и подписи продуктов в код не идут — платформа запрещает
/// хардкодить их в UI пейвола, они приходят из `MonetizationProduct`. Список
/// SKU подписок (`subscriptionProductIDs`) — исключение: он нужен не UI,
/// а локальному StoreKit-источнику entitlement платформы.
///
/// Спецпредложение (`specialOffer*`) остаётся плейсхолдером из reference-проекта
/// `Claude232` — цены и период спецпредложения приходят из продукта Adapty,
/// а не хардкодятся.
///
/// Контекст — `docs/specs/2026-08-20-gemini-design.md`, раздел «Временные значения».
enum DevelopmentConfiguration {
    // MARK: Идентификаторы приложения

    /// Настоящий идентификатор сборки, а не константа: в Debug он оканчивается
    /// на `.dev`, чтобы приложение ставилось на личный телефон разработчика.
    /// StoreKit сверяет `appBundleID` транзакции именно с ним — подставив сюда
    /// релизный, мы бы отвергали собственные покупки в Debug.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.ras.5137g4m769"

    // MARK: Монетизация

    static let adaptyPublicKey = "public_live_kQTFVDB0.M6nYJkcxFUgxZ3WOYv8i"
    /// Уровень доступа в Adapty — одинаковый во всех приложениях компании.
    static let adaptyAccessLevel = "premium"

    /// SKU из App Store Connect, которые продают подписку Pro. Нужны
    /// `ApplePremiumProductCatalog` — локальному источнику entitlement, который
    /// подтверждает подписку по `Transaction.currentEntitlements`, даже если
    /// Adapty недоступен. Это не хардкод цены в UI (тот запрещён платформой) —
    /// цены и подписи по-прежнему берутся из `MonetizationProduct.displayPrice`.
    static let subscriptionProductIDs = [
        "weekly_9.99_nottrial",
        "monthly_19.99_nottrial",
        "yearly_59.99_nottrial",
        "offer_week_4.99_nottrial"
    ]

    // MARK: Юридические ссылки

    static let privacyPolicyURL = URL(
        string: "https://docs.google.com/document/d/1FTMFm7Dc0reZ9BY4evbHDTmWY2yq1dVdMM9oxmp89PQ/edit"
    )!
    static let termsOfUseURL = URL(
        string: "https://docs.google.com/document/d/1afeYuH3U_G9PDLPRTCcxMiVvIKaN0skHjIlW5c8pFIo/edit"
    )!
    /// Почта поддержки 5137 — из карточки Kaiten, настоящая.
    ///
    /// Гугл-формы здесь быть не должно: у формы нет ни идентификатора
    /// аккаунта, ни версии сборки, и поддержке приходится выспрашивать их
    /// у человека, который уже расстроен. Правило тимлида, оно же
    /// в общем `~/.claude/CLAUDE.md`.
    static let supportEmail = "dyahdiyaning8689@gmail.com"

    /// Ссылка на App Store в тексте — сам «Share with friends» не прикладывает URL
    /// отдельно (см. `MainSceneModel.share(_:file:)`), только когда шарится файл.
    static let shareMessage = String(
        localized: "Fenuko Flow — chat with AI, generate images and videos. https://apps.apple.com/us/app/fenuko-flow/id6805904639"
    )

    // MARK: Спецпредложение

    /// Скидка, название, цена и зачёркнутая цена больше не живут здесь: они
    /// считаются из продукта Adapty в `PaywallPlanFactory.specialOffer`.
    ///
    /// ВРЕМЕННО: окно предложения. Настоящий срок задаёт `SpecialOfferConfiguration`,
    /// а отсчёт обязан идти от серверного времени, а не от часов устройства.
    static let specialOfferDuration: Duration = .seconds(23 * 3600 + 59 * 60 + 42)
}
