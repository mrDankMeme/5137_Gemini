import BroadMonetization
import Foundation
import SwiftUI
import UIKit

/// Состояние основной части приложения: переписка, каталог, навигация.
///
/// Модель работает только с use case'ами домена. Откуда приходят данные —
/// из заглушки или из сети — она не знает и знать не должна.
@Observable
@MainActor
final class MainSceneModel {
    // MARK: Переписка

    var messages: [ChatMessage] = []
    var chatTitle = MainSceneModel.newChatTitle
    var isGenerating = false
    /// Идёт ответ с поиском в интернете — лоадер подписывает, чем занят.
    private(set) var isSearchingWeb = false
    /// История выбранной переписки ещё грузится. Пока это так, экран показывает
    /// чат с лоадером, а не главный экран: иначе при открытии чата из меню
    /// на секунду возвращается пустой «Ready when you are».
    private(set) var isLoadingHistory = false
    var notice: ChatNoticeBanner.Kind?
    /// Сообщение о неудавшемся действии. Записи выполняются оптимистично,
    /// но при отказе состояние откатывается, и пользователь об этом узнаёт —
    /// молча «удавшееся» удаление хуже, чем честная ошибка.
    var actionFailure: String?
    var toast: ToastMessage?
    /// Идёт сохранение в фотоплёнку. Ставится синхронно, до первого `await`:
    /// повторное нажатие не должно заводить вторую загрузку.
    var isSavingGeneration = false
    /// Только что сохранённая генерация — кнопка на пару секунд показывает
    /// галочку вместо иконки. Загрузка ролика может идти долго, и спиннер,
    /// который просто гаснет по завершении, легко принять за то, что кнопка
    /// так и не сработала.
    var savedGenerationID: LibraryItem.ID?
    /// Готовим файл к отправке. Ролик весит десятки мегабайт, и без отклика
    /// нажатие выглядит так, будто кнопка не сработала.
    var isPreparingShare = false
    /// Какой чат открыт. Нужен переименованию и удалению.
    private(set) var currentChatID: ChatSummary.ID?

    /// Показывать переписку, а не главный экран.
    var isConversationVisible: Bool {
        !messages.isEmpty || isLoadingHistory
    }

    /// Название, под которым чат живёт, пока сервер не дал ему своё.
    static let newChatTitle = String(localized: "New Chat")

    // MARK: Каталог и аккаунт

    var models: [AIModel] = []
    var selectedModelID: AIModel.ID = "" {
        didSet {
            // У генерации нет ответа, который можно было бы искать в интернете,
            // и тумблера в поле ввода для неё нет. Оставленный включённым режим
            // ушёл бы в запрос молча — и стоил бы дороже ни за что.
            if supportsGenerationSettings {
                chatMode = .general
            }
        }
    }

    var chats: [ChatSummary] = []
    var libraryItems: [LibraryItem] = []
    var balance: ProButton.Content = .upgrade
    var accountID = "—"

    /// Баланс словами — для письма в поддержку.
    var balanceDescription: String {
        switch balance {
        case .pro: "pro"
        case .upgrade: "0"
        case let .tokenBalance(amount): amount.formatted(.number.precision(.fractionLength(0 ... 2)))
        }
    }

    /// Выбранная модель. По ней экран решает, показывать ли параметры генерации.
    var selectedModel: AIModel? {
        models.first { $0.id == selectedModelID }
    }

    /// Параметры генерации есть только у моделей изображений и видео.
    var supportsGenerationSettings: Bool {
        switch selectedModel?.capability {
        case .image, .video: true
        default: false
        }
    }

    // MARK: Ввод

    /// Текст в поле ввода. Живёт в модели, а не в экране: диктовке нужно положить
    /// распознанное **в то же поле**, а экран под ней меняется — главный на чат.
    var draft = ""
    var voice: VoiceInputState?
    /// Отказ в правах на микрофон или распознавание. Чинится только в настройках iOS,
    /// поэтому это не обычная ошибка, а отдельный алерт с переходом туда.
    var permissionFailure: String?
    var generationSettings = GenerationSettings()
    /// Режим ответа. Переключается тумблером в поле ввода и уходит в запрос:
    /// поиск в интернете у backend — это режим генерации, а не отдельная ручка.
    var chatMode: ChatMode = .general
    /// Файлы, выбранные для следующего сообщения.
    var pendingAttachments: [ChatAttachment] = []
    /// Кеш `AIConsentPolicy.hasAccepted()`: `send()` синхронный и не может
    /// дожидаться диска на каждое нажатие.
    private var hasAcceptedAIConsent = false
    /// Экран уже открывался и был отклонён — на повторном показе это меняет
    /// подсказку сверху: не первое знакомство, а причина, почему отправка
    /// не прошла.
    private(set) var hasDeclinedAIConsent = false
    /// Текст попытки, заблокированной экраном согласия. Согласие — не тупик,
    /// а продолжение той же отправки: без этого поля пришлось бы жать
    /// «Отправить» второй раз, хотя человек уже это сделал.
    private var pendingConsentMessage: String?

    // MARK: Навигация

    /// Что показано поверх основного экрана. Один источник правды вместо россыпи
    /// булевых флагов: два `fullScreenCover` одновременно показать нельзя.
    var cover: MainSceneCover?

    /// Открыто ли боковое меню. Меню — не модальное окно, а слой того же экрана,
    /// поэтому шторки и пейволы поверх него показываются обычным способом,
    /// без отдельных слотов «поверх меню».
    var isMenuOpen = false {
        didSet {
            // Имя переписке даёт сервер по первому сообщению, но отдаёт его
            // только в списке — в ответе на отправку заголовка нет. Без
            // перечитывания список и шапка остаются с «New Chat» до
            // перезапуска приложения.
            if isMenuOpen, !oldValue {
                Task { await refreshChats() }
            }
        }
    }

    var sheet: MainSceneSheet?
    /// Что уходит в `.sheet`. Просьба оценить сюда не попадает: в макете это
    /// центрированный алерт, и он рисуется слоем поверх сцены — иначе с него
    /// не поднять системное окно оценки, которое идёт следом за согласием.
    var presentedSheet: MainSceneSheet? {
        get { sheet == .rateUsPrompt ? nil : sheet }
        set { sheet = newValue }
    }

    var shareItem: ShareItem?
    /// Стек экранов, открытых из меню: история, библиотека, настройки. Живёт
    /// на основном экране, а не внутри меню: в макете это полноэкранные экраны,
    /// и внутри ящика им места нет.
    var menuPath: [MenuRoute] = []
    var isModelPickerPresented = false
    var isGenerationReadyBannerPresented = false

    // MARK: Выбор в пейволе

    /// Позиция выбранного продукта, а не SKU: Adapty может вернуть дубликаты.
    var selectedPlanIndex: Int?
    var selectedTokenPackageIndex: Int?
    var isPurchasing = false
    var isRestoring = false

    // MARK: Настройки

    /// Пока не посчитали — прочерк, а не «0 MB»: ноль означал бы «чисто»,
    /// хотя мы просто ещё не смотрели.
    var cacheSize = "—"
    /// Данные экрана «Current plan». Пока не спросили — `nil`, и экран рисует
    /// «Free»: выдуманные «PRO до 25 апреля» там стояли захардкоженными.
    var currentPlanName: String?
    var currentPlanPeriod: String?
    var isClearingCache = false
    let appVersion = Bundle.main.appVersion
    private(set) var specialOfferEndsAt = Date()

    private let dependencies: MainSceneDependencies
    /// Не `private`: отладочные сиды в Debug ждут его загрузку, прежде чем
    /// открывать пейволы.
    let paywallCatalog: PaywallCatalog
    private var generationTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private let dictation = SpeechDictation()
    /// Момент начала диктовки — из него считается таймер на дорожке звука.
    private var dictationStartedAt: Date?
    private var dictationTicker: Task<Void, Never>?
    /// Номер текущей генерации. Отменённая задача может дописаться уже после того,
    /// как началась следующая, — по номеру видно, что убирать за собой ей нечего.
    private var generationID = 0
    /// `generationTask` сейчас — картинка или видео, а не текстовый ответ.
    ///
    /// У медиа-генерации нет сессии чата: задача уходит в `/v1/media/*`,
    /// сервер получает и списывает кредиты сразу по создании job'а, а клиент
    /// только опрашивает готовность. Отменить такую задачу с уходом из чата —
    /// не значит остановить её на сервере: job продолжает жить, кредиты уже
    /// списаны, а локальный архив (`GenerationArchive`), в который переписка
    /// пишется по завершении, не получает ни строки — вся переписка исчезает
    /// без следа и без ошибки. Текстовый ответ так не потерять: у него есть
    /// настоящая серверная сессия чата независимо от того, успел клиент
    /// дождаться ответа или нет.
    private var isGeneratingMedia = false
    /// Вложения отправленных сообщений, по чату и порядковому номеру сообщения
    /// пользователя. История с сервера их не возвращает — она отдаёт только
    /// текстовые блоки, — и без этого при возврате в чат из меню пузырь
    /// оказывался пустым: фото, которое пользователь только что приложил,
    /// исчезало. Тот же баг ловили в 232.
    private var sentAttachments: [ChatSummary.ID: [Int: [ChatAttachment]]] = [:]
    /// Номер текущей загрузки истории — та же защита для открытия чатов подряд.
    private var historyLoadID = 0

    init(dependencies: MainSceneDependencies, paywallCatalog: PaywallCatalog) {
        self.dependencies = dependencies
        self.paywallCatalog = paywallCatalog
    }

    /// Первичная загрузка. Ошибки не роняют экран: без каталога он просто пуст,
    /// а не сломан — платформа требует переживать 0 продуктов и пустые списки.
    func load() async {
        // Пять независимых запросов — пять параллельных, а не цепочка: последовательно
        // с настоящим backend экран был бы неверным до последнего ответа.
        async let loadedModels = try? await dependencies.loadModels()
        async let loadedChats = try? await dependencies.loadChats()
        async let loadedLibrary = try? await dependencies.loadLibrary()
        async let loadedAccount = try? await dependencies.loadAccount()
        async let entitlementStatus = paywallCatalog.currentEntitlementStatus()

        models = Self.deduplicated(await loadedModels ?? [])
        // Каталог мог не долететь — одна повторная попытка. Без неё экран
        // остаётся с пустым списком до перезапуска приложения.
        if models.isEmpty {
            models = Self.deduplicated((try? await dependencies.loadModels()) ?? [])
        }
        // Основную модель называет backend; первая в списке ею быть не обязана.
        selectedModelID = (models.first(where: \.isDefault) ?? models.first)?.id ?? ""
        // Пакеты токенов подписаны тем, сколько это генераций. Цену знает
        // только каталог генерации — до него у пейвола этой строки нет.
        paywallCatalog.updateGenerationPrice(models.compactMap(\.credits).min())
        chats = await loadedChats ?? []
        libraryItems = await loadedLibrary ?? []

        var isPro = await entitlementStatus == .active
        if let account = await loadedAccount {
            accountID = account.id
            // Синк на каждом холодном старте, а не только сразу после покупки:
            // подписка у Adapty/StoreKit встаёт локально мгновенно, а бэк узнаёт
            // о ней только из вебхука — асинхронного и способного не долететь.
            // Идемпотентно, поэтому звать безопасно каждый раз.
            await paywallCatalog.syncSubscriptionPurchase(userID: account.id)
            // Тот же принцип, что в 232 (`max(adaptyEnd, russianEnd, backendEnd)`):
            // бэкенд — не запасной путь только на Debug, а постоянный второй
            // источник правды. Он подтверждает то, что платформа могла не
            // увидеть — в Debug это тестовая транзакция `Debug.storekit`
            // с локальным корнем Xcode, в проде так же понадобится для
            // RU-платежей, которые Adapty не видит вовсе.
            isPro = isPro || account.isSubscribedOnBackend
            // В макете два состояния кнопки: у пользователя с токенами — их число,
            // у остальных — предложение оформить Pro. Настоящий подписчик без
            // токенов — тоже «Pro», просто по правде, не как апсейл.
            // Число важнее самой подписки: у подписчика с токенами бейдж
            // обязан их показывать, а не «Pro» — то же самое «Pro», просто
            // без данных, которые сейчас как раз есть. «Pro» остаётся только
            // там, где показывать нечего — без токенов или без подписки.
            balance = account.tokenBalance > 0 ? .tokenBalance(account.tokenBalance)
                : isPro ? .pro : .upgrade
        }

        hasAcceptedAIConsent = await dependencies.aiConsentPolicy.hasAccepted()

        #if DEBUG
            applyDebugSeedIfNeeded()
        #endif

        // Вход в приложение — по определению уже после пейвола, значит это
        // тот момент, когда согласие нужно спросить, если его ещё не дали.
        // Не поверх сида отладки: он ставит cover нарочно, под конкретный экран.
        if !hasAcceptedAIConsent, cover == nil {
            cover = .aiConsent
        }
    }

    /// Каталог приходит с повторами: «Nano Banana 2» и «Nano Banana Pro» стоят
    /// в списке дважды с одинаковыми названием и подписью. Различить их
    /// пользователь не может, поэтому вторая карточка — не выбор, а мусор.
    ///
    /// Схлопываем по паре «название + возможность», сохраняя порядок сервера
    /// и оставляя первую запись. Это не фильтрация каталога по нашему вкусу:
    /// каждая различимая модель остаётся на месте.
    private static func deduplicated(_ models: [AIModel]) -> [AIModel] {
        var seen = Set<String>()
        return models.filter { model in
            seen.insert("\(model.title)|\(model.capability)").inserted
        }
    }

    // MARK: Спецпредложение

    /// Показывает предложение после закрытия пейвола — правило дома, как в 232.
    ///
    /// Условия те же: кампания включена продактом в remote config, подписки нет,
    /// поверх ничего не открыто и окно кампании ещё не истекло. Любое из них
    /// не сошлось — молча ничего не делаем.
    func presentSpecialOfferIfEligible() async {
        // Каталог может ещё грузиться: вызов присоединяется к идущей загрузке,
        // а не начинает новую. Без этого проверка ниже читала бы пустоту.
        await paywallCatalog.load()

        guard paywallCatalog.isSpecialOfferEnabled,
              paywallCatalog.specialOffer != nil,
              // `.pro` — не единственное подписное состояние: подписчик
              // с токенами показывает их число, а не «Pro». Настоящая
              // проверка — не «upgrade», а не конкретное значение бейджа.
              balance == .upgrade,
              cover == nil, sheet == nil,
              await dependencies.specialOfferPolicy.hasActiveWindow()
        else {
            return
        }

        specialOfferEndsAt = await dependencies.specialOfferPolicy.beginWindowIfNeeded(
            duration: paywallCatalog.specialOfferRemote?.windowDuration
        )
        cover = .paywall(.specialOffer)
    }

    // MARK: Текущий тариф

    func refreshCurrentPlan() async {
        let subscription = await paywallCatalog.currentSubscription()
        currentPlanName = subscription.isActive
            ? String(localized: "PRO")
            : String(localized: "Free")

        guard subscription.isActive else {
            currentPlanPeriod = nil
            return
        }
        if subscription.isLifetime {
            currentPlanPeriod = String(localized: "Lifetime")
        } else if let expiresAt = subscription.expiresAt {
            currentPlanPeriod = String(
                localized: "until \(expiresAt.formatted(date: .abbreviated, time: .omitted))"
            )
        } else {
            // Подписка активна, но срок платформа не назвала — молчим,
            // а не подставляем дату.
            currentPlanPeriod = nil
        }
    }

    // MARK: Буфер обмена

    /// Копирование невидимо, поэтому всегда с подтверждением: иначе непонятно,
    /// сработала кнопка или палец промахнулся мимо иконки.
    func copy(_ text: String, confirmation: String) {
        UIPasteboard.general.string = text
        toast = .copied(confirmation)
    }

    // MARK: Кеш

    func refreshCacheSize() async {
        cacheSize = Self.formatted(await ResponseCacheStorage.size())
    }

    func clearCache() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }
        cacheSize = Self.formatted(await ResponseCacheStorage.clear())
        // Без подтверждения нажатие выглядит холостым: размер меняется на
        // сотни килобайт, этого в строке просто не замечаешь, а на свежей
        // установке чистить почти нечего и число не меняется вовсе.
        toast = ToastMessage(icon: "trash", text: String(localized: "Cache cleared"))
    }

    private static func formatted(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    // MARK: Покупки

    /// Возвращает `true`, если пейвол можно закрыть — подписка/токены зачислены.
    @discardableResult
    func purchaseSubscription() async -> Bool {
        guard let index = selectedPlanIndex, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        guard let attempt = await paywallCatalog.purchaseSubscription(at: index) else { return false }
        return await handle(attempt, grantKind: .subscription)
    }

    /// В плейсменте спецпредложения продукт один, выбирать нечего — поэтому
    /// без `selectedIndex`, в отличие от подписки и пакетов токенов.
    @discardableResult
    func purchaseSpecialOffer() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        guard let attempt = await paywallCatalog.purchaseSpecialOffer() else { return false }
        return await handle(attempt, grantKind: .subscription)
    }

    @discardableResult
    func purchaseTokenPackage() async -> Bool {
        guard let index = selectedTokenPackageIndex, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        guard let attempt = await paywallCatalog.purchaseTokenPackage(at: index) else { return false }
        return await handle(attempt, grantKind: .wallet)
    }

    private enum PurchaseGrantKind {
        case subscription
        case wallet

        #if DEBUG
            var debugAdminGrantKind: DebugAdminGrant.Kind {
                switch self {
                case .subscription: .subscription
                case .wallet: .wallet
                }
            }
        #endif
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        guard !isRestoring else { return false }
        isRestoring = true
        defer { isRestoring = false }

        switch await paywallCatalog.restore() {
        case .restored:
            await paywallCatalog.syncSubscriptionPurchase(userID: accountID)
            await refreshAccountAndEntitlement()
            return true
        case .nothingFound:
            actionFailure = String(localized: "No purchases to restore.")
            return false
        case let .unavailable(error), let .failed(error):
            actionFailure = error.userMessage
            return false
        }
    }

    /// `true` значит «пейвол можно закрыть». Отмена и «покупка ожидает
    /// подтверждения» (Ask to Buy, семейный доступ) не ошибки — экран просто
    /// остаётся открытым, без баннера с текстом.
    private func handle(
        _ attempt: PaywallCatalog.PurchaseAttempt,
        grantKind: PurchaseGrantKind
    ) async -> Bool {
        switch attempt.outcome {
        case .activated, .completed, .completedButUnverified:
            // Реальный путь — как у 232: клиент репортит бэку подписанную
            // StoreKit-транзакцию, бэк сам проверяет подпись Apple. Работает
            // одинаково в sandbox и в проде. `DebugAdminGrant` — только запасной
            // путь на случай, если этот синк не прошёл (ручки на бэке ещё нет,
            // сеть легла и т.п.), и только в Debug.
            let synced = switch grantKind {
            case .subscription: await paywallCatalog.syncSubscriptionPurchase(userID: accountID)
            case .wallet: await paywallCatalog.syncTokenPurchase(attempt.product, userID: accountID)
            }
            #if DEBUG
                if !synced {
                    // Отказ показываем: молчаливое «купил, а баланс прежний»
                    // тестер читает как сломанную покупку и идёт разбираться
                    // не туда.
                    let failure = await DebugAdminGrant.grant(
                        kind: grantKind.debugAdminGrantKind,
                        accountID: accountID,
                        productID: attempt.product.productID.rawValue
                    )
                    if let failure {
                        report(failure: failure)
                    }
                }
            #endif
            await refreshAccountAndEntitlement()
            return true
        case .cancelled, .pending:
            return false
        case let .failed(error):
            #if DEBUG
                // В Debug покупка обязана доходить до конца, как в проде.
                // Транзакция из `Debug.storekit` подписана локальным корнем
                // Xcode, поэтому её отвергает и проверка бэка, и порой сама
                // Adapty — при этом пользователь нажал «купить» и вправе увидеть
                // результат. Зачисляем напрямую, как это делает 232.
                await DebugAdminGrant.grant(
                    kind: grantKind.debugAdminGrantKind,
                    accountID: accountID,
                    productID: attempt.product.productID.rawValue
                )
                await refreshAccountAndEntitlement()
                return true
            #else
                actionFailure = error.userMessage
                return false
            #endif
        }
    }

    private func refreshAccountAndEntitlement() async {
        async let loadedAccount = try? await dependencies.loadAccount()
        async let entitlementStatus = paywallCatalog.currentEntitlementStatus()
        var isPro = await entitlementStatus == .active
        if let account = await loadedAccount {
            accountID = account.id
            // См. комментарий в `load()`: бэкенд — второй постоянный источник
            // правды, не только запасной путь на Debug.
            isPro = isPro || account.isSubscribedOnBackend
            // Число важнее самой подписки: у подписчика с токенами бейдж
            // обязан их показывать, а не «Pro» — то же самое «Pro», просто
            // без данных, которые сейчас как раз есть. «Pro» остаётся только
            // там, где показывать нечего — без токенов или без подписки.
            balance = account.tokenBalance > 0 ? .tokenBalance(account.tokenBalance)
                : isPro ? .pro : .upgrade
        }
    }

    // MARK: Навигация

    /// Куда ведёт кнопка баланса в шапке — зависит от того, что на ней написано.
    ///
    /// Цифра токенов — это пакеты, а не подписка: человек жмёт её, чтобы докупить
    /// («N tokens. Buy more» — так она и называется для VoiceOver), а «Go Pro»
    /// на этом месте подменяет действие. Подписчику Go Pro тем более не нужен,
    /// а кредиты за генерацию списываются и у него — ему тоже пакеты.
    func openBalance() {
        // Куда именно — решает `openPaywall`: без подписки пакеты недоступны,
        // и он сам развернёт на неё.
        openPaywall(balance == .upgrade ? .subscription : .tokens)
    }

    /// Второе согласие дату не переставляет — правило и отметка живут
    /// в `AIConsentPolicy`, здесь только сама реакция на экран.
    func acceptAIConsent() {
        hasAcceptedAIConsent = true
        cover = nil
        Task { [dependencies] in
            await dependencies.aiConsentPolicy.accept()
        }
        // Экран мог перехватить настоящую попытку отправить сообщение —
        // тогда согласие её продолжает, а не просто закрывается само по себе.
        if let pendingConsentMessage {
            send(pendingConsentMessage)
        }
    }

    /// Отказ не тупик: экран закрывается, а согласие снова спросится при
    /// следующей попытке отправить сообщение или запустить генерацию.
    func declineAIConsent() {
        hasDeclinedAIConsent = true
        cover = nil
    }

    func openPaywall(_ requested: PaywallKind) {
        // Два правила, и оба здесь, а не на каждой кнопке, — чтобы их не
        // забыли в новом месте.
        //
        // Токены существуют только поверх подписки: бэкенд на покупку без неё
        // отвечает `403 subscription_required`. Значит без подписки любой путь
        // ведёт на подписку, а не в пакеты — иначе человек покупает то, что
        // не сработает.
        var kind = requested
        if kind == .tokens, balance == .upgrade {
            kind = .subscription
        }
        // И наоборот: подписчику пейвол подписки не показывается никогда и
        // ниоткуда — ни строкой настроек, ни баннером лимита, ни
        // спецпредложением. Купить ему там нечего. `.pro` — не единственное
        // подписное состояние бейджа: с токенами он показывает их число.
        if kind != .tokens, balance != .upgrade {
            return
        }
        // Без предложения экран рисовать нечем, а открытое окно поверх сцены
        // осталось бы чёрным и без выхода — закрыть его нечем.
        if kind == .specialOffer {
            guard paywallCatalog.specialOffer != nil else { return }
            // Отсчёт начинается в момент показа: иначе экран открывается
            // с уже истёкшим таймером и сам себя закрывает.
            prepareSpecialOffer()
        }
        cover = .paywall(kind)
    }

    func present(_ sheet: MainSceneSheet) {
        self.sheet = sheet
    }

    func share(_ text: String, file: URL? = nil) {
        shareItem = ShareItem(text: text, url: file)
    }

    /// Делимся **файлом**, а не ссылкой на него.
    ///
    /// Со ссылкой системная шторка считает генерацию веб-страницей: показывает
    /// домен, несколько секунд тянет превью по сети и предлагает «Копировать»
    /// и «Список для чтения» вместо «Сохранить видео».
    func shareGeneration(_ item: LibraryItem, text: String) {
        guard !isPreparingShare else { return }
        isPreparingShare = true

        Task { [weak self] in
            defer { self?.isPreparingShare = false }
            let file = try? await GenerationFileStore.shared.file(for: item)
            guard let self else { return }
            guard let file else {
                report(failure: String(localized: "Couldn’t prepare the file to share"))
                return
            }
            shareItem = ShareItem(text: text, url: file)
        }
    }

    /// Открывает экран из меню: закрывает ящик и кладёт маршрут в основной стек.
    func openFromMenu(_ route: MenuRoute) {
        isMenuOpen = false
        menuPath.append(route)
    }

    /// Повторить генерацию можно, если известно, чем и по какому запросу она
    /// сделана, и модель ещё есть в каталоге.
    func canRegenerate(_ item: LibraryItem) -> Bool {
        guard let prompt = item.prompt, !prompt.isEmpty, let modelID = item.modelID else {
            return false
        }
        return models.contains { $0.id == modelID }
    }

    /// Повтор: тот же запрос той же моделью, но новой перепиской — прежняя
    /// генерация остаётся в библиотеке, её не подменяем.
    func regenerate(_ item: LibraryItem) {
        guard canRegenerate(item), let prompt = item.prompt, let modelID = item.modelID else {
            return
        }
        cover = nil
        startNewChat()
        selectedModelID = modelID
        send(prompt)
    }

    func openGeneration(_ item: LibraryItem) {
        cover = .generation(item)
    }

    /// Срок окна называет кампания в remote config — тот же источник, по
    /// которому решается, показывать ли предложение вообще. Константа осталась
    /// запасной: без неё таймер на экране жил бы своей жизнью и мог обещать
    /// сутки там, где продакт задал час.
    private func prepareSpecialOffer() {
        let duration = paywallCatalog.specialOfferRemote?.windowDuration
            ?? TimeInterval(DevelopmentConfiguration.specialOfferDuration.components.seconds)
        specialOfferEndsAt = Date().addingTimeInterval(duration)
    }

    // MARK: Переписка

    func send(_ text: String) {
        // Платформа требует переводить UI в работу синхронно — до `Task`
        // и первого `await`, чтобы кнопка сразу блокировалась.
        guard !isGenerating else { return }
        // Отправка сообщения и запуск генерации идут одним и тем же путём —
        // это единственная точка, через которую то и другое уходит на сервер.
        // Отказавшийся не в тупике: тот же текст остаётся в поле, а согласие
        // спросится снова при следующей попытке. Согласившийся не должен жать
        // «Отправить» второй раз — эта же попытка уходит сама.
        guard hasAcceptedAIConsent else {
            pendingConsentMessage = text
            cover = .aiConsent
            return
        }
        pendingConsentMessage = nil
        generationTask?.cancel()
        isGenerating = true
        // Поле чистится только когда отправка действительно уходит: иначе
        // отклонённое сообщение пропадает вместе с набранным текстом.
        draft = ""

        let attachments = pendingAttachments
        pendingAttachments.removeAll()
        let userMessageIndex = messages.filter { $0.author == .user }.count

        messages.append(ChatMessage(
            id: UUID().uuidString,
            author: .user,
            text: text,
            attachments: attachments
        ))
        let placeholder = ChatMessage(
            id: UUID().uuidString,
            author: .assistant,
            text: "",
            status: .inProgress
        )
        messages.append(placeholder)

        let chatID = currentChatID
        let modelID = selectedModelID
        let mode = chatMode
        isSearchingWeb = mode.searchesWeb
        generationID &+= 1
        let generation = generationID
        // Генерация идёт своим путём: у неё отдельный каталог моделей и
        // отдельные ручки. Переписка её не заводит — на просьбу «нарисуй»
        // чат-модель отвечает словесным описанием картинки.
        let mediaKind: LibraryItem.Kind? = switch selectedModel?.capability {
        case .image: .image
        case .video: .video
        default: nil
        }
        let mediaModel = selectedModel
        let settings = generationSettings
        isGeneratingMedia = mediaKind != nil

        generationTask = Task { [weak self] in
            if let mediaKind, let mediaModel {
                await self?.produceGeneration(
                    for: placeholder.id,
                    prompt: text,
                    kind: mediaKind,
                    chatID: chatID,
                    model: mediaModel,
                    settings: settings,
                    attachments: attachments,
                    generation: generation
                )
            } else {
                await self?.produceReply(
                    for: placeholder.id,
                    text: text,
                    attachments: attachments,
                    chatID: chatID,
                    modelID: modelID,
                    mode: mode,
                    generation: generation,
                    userMessageIndex: userMessageIndex
                )
            }
        }
    }

    func stop() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        isSearchingWeb = false

        guard let index = messages.lastIndex(where: { $0.status == .inProgress }) else { return }
        if messages[index].text.isEmpty {
            // Ответ не успел начаться — пустой пузырь в переписке не нужен.
            messages.remove(at: index)
        } else {
            messages[index].status = .complete
        }
    }

    /// Повтор упавшего ответа и перегенерация готового — одно действие с точки
    /// зрения пользователя, но разные состояния: у первого ответ есть и он `.failed`,
    /// у второго — `.complete`.
    ///
    /// Запрос берётся у сообщения, **непосредственно предшествующего** ответу,
    /// вместе с его вложениями. Раньше брался последний пользовательский текст
    /// вообще, а вложения терялись — оплаченный повтор уходил с другим запросом.
    func regenerate(messageID: ChatMessage.ID) {
        guard !isGenerating,
              let index = messages.firstIndex(where: { $0.id == messageID }),
              let promptIndex = messages[..<index].lastIndex(where: { $0.author == .user })
        else {
            return
        }

        let prompt = messages[promptIndex]
        generationTask?.cancel()
        isGenerating = true
        messages[index].status = .inProgress
        messages[index].text = ""
        messages[index].generation = nil

        let chatID = currentChatID
        let modelID = selectedModelID
        let mode = chatMode
        isSearchingWeb = mode.searchesWeb
        generationID &+= 1
        let generation = generationID
        generationTask = Task { [weak self] in
            await self?.produceReply(
                for: messageID,
                text: prompt.text,
                attachments: prompt.attachments,
                chatID: chatID,
                modelID: modelID,
                mode: mode,
                generation: generation,
                // Перегенерация не добавляет нового сообщения пользователя:
                // вложения у него уже записаны.
                userMessageIndex: -1
            )
        }
    }

    func rename(to title: String) {
        guard let chatID = currentChatID else {
            chatTitle = title
            return
        }

        let previousTitle = chatTitle
        let previousChats = chats
        chatTitle = title
        chats = chats.map { $0.id == chatID ? ChatSummary(id: $0.id, title: title) : $0 }

        Task { [weak self, dependencies] in
            do {
                try await dependencies.renameChat(chatID: chatID, to: title)
            } catch {
                guard let self else { return }
                chatTitle = previousTitle
                chats = previousChats
                report(failure: String(localized: "Couldn’t rename the chat"))
            }
        }
    }

    func deleteCurrentChat() {
        guard let chatID = currentChatID else {
            startNewChat()
            return
        }

        let previousChats = chats
        chats.removeAll { $0.id == chatID }
        startNewChat()

        Task { [weak self, dependencies] in
            do {
                try await dependencies.deleteChat(chatID: chatID)
            } catch {
                guard let self else { return }
                chats = previousChats
                report(failure: String(localized: "Couldn’t delete the chat"))
            }
        }
    }

    /// Подсказка с главного экрана: текст падает в поле ввода, отправляет
    /// человек сам.
    ///
    /// Раньше нажатие отправляло сразу, и «Create Image» уходило выбранной
    /// чат-модели — та картинку не рисует и отвечала её описанием словами.
    /// Поэтому шаблоны генерации ещё и переключают модель: рисует модель
    /// изображений, снимает — модель видео. Для остальных модель не трогаем,
    /// человек мог выбрать её осознанно.
    func applySuggestion(_ action: SuggestedAction) {
        if let capability = action.capability,
           let model = models.first(where: { $0.capability == capability })
        {
            selectedModelID = model.id
        }
        draft = action.prompt
    }

    /// Уход с экрана не должен обрывать картинку или видео на полпути: job
    /// уже создан на сервере, кредиты уже списаны, а единственная запись
    /// о переписке появится в `GenerationArchive` только по завершении —
    /// отменённая задача до этого места не доходит, и вся переписка исчезает
    /// без следа. Поэтому такую задачу не отменяем, а просто отпускаем: она
    /// доработает сама, найдёт архив без надобности в live-состоянии экрана
    /// и молча сохранится — сама генерация всё равно всплывёт в библиотеке.
    /// Текстовый ответ так не потерять — его смело отменяем как раньше.
    private func detachOrCancelGenerationTask() {
        if isGeneratingMedia, generationTask != nil {
            toast = ToastMessage(icon: "clock", text: String(localized: "Generation continues in the background"))
        } else {
            generationTask?.cancel()
        }
        generationTask = nil
        isGenerating = false
    }

    func startNewChat() {
        detachOrCancelGenerationTask()
        historyLoadID &+= 1
        isLoadingHistory = false
        pendingAttachments.removeAll()
        messages.removeAll()
        notice = nil
        voice = nil
        chatTitle = Self.newChatTitle
        currentChatID = nil
        menuPath.removeAll()
        isMenuOpen = false
        cover = nil
    }

    func openChat(_ chat: ChatSummary) {
        detachOrCancelGenerationTask()
        notice = nil
        voice = nil
        pendingAttachments.removeAll()

        chatTitle = chat.title
        currentChatID = chat.id
        menuPath.removeAll()
        isMenuOpen = false
        cover = nil

        // Переписка прежнего чата убирается **синхронно**: иначе под новым
        // заголовком секунду висят чужие сообщения.
        messages.removeAll()
        isLoadingHistory = true
        historyLoadID &+= 1
        let load = historyLoadID

        Task { [weak self, dependencies] in
            let loaded = (try? await dependencies.loadMessages(chatID: chat.id)) ?? []
            guard let self, historyLoadID == load else { return }
            let restored = restoringAttachments(in: loaded, chatID: chat.id)
            // Не присваивание, а подклейка: пока история летела, пользователь мог
            // успеть отправить сообщение — присваивание стёрло бы его вместе с ответом.
            messages = restored + messages
            isLoadingHistory = false
        }
    }

    /// Возвращает вложения в загруженную историю: сервер отдаёт только текст,
    /// поэтому подставляем то, что сами же отправили в этой сессии.
    private func restoringAttachments(
        in loaded: [ChatMessage],
        chatID: ChatSummary.ID
    ) -> [ChatMessage] {
        guard let stored = sentAttachments[chatID], !stored.isEmpty else {
            return loaded
        }
        var index = 0
        return loaded.map { message in
            guard message.author == .user else { return message }
            defer { index += 1 }
            guard let attachments = stored[index] else { return message }
            var restored = message
            restored.attachments = attachments
            return restored
        }
    }

    /// Какой пикер открыт. Пикер поднимается после закрытия шторки выбора —
    /// с самой шторки второе модальное окно не поднять.
    var attachmentSource: AttachmentSource?

    /// Добавляет выбранные файлы к следующему сообщению.
    ///
    /// Больше `attachmentLimit` в одно сообщение не уходит: до спецификации
    /// backend неизвестно, сколько он примет, а на реальной сети безлимитный
    /// выбор упрётся в размер запроса.
    func attach(_ attachments: [ChatAttachment]) {
        let free = Self.attachmentLimit - pendingAttachments.count
        guard free > 0 else {
            actionFailure = String(localized: "You can attach up to \(Self.attachmentLimit) files to one message.")
            return
        }
        pendingAttachments.append(contentsOf: attachments.prefix(free))
        if attachments.count > free {
            actionFailure = String(localized: "You can attach up to \(Self.attachmentLimit) files to one message.")
        }
    }

    static let attachmentLimit = 6

    func removeAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    // MARK: Библиотека

    func deleteGeneration(_ item: LibraryItem) {
        let previousItems = libraryItems
        libraryItems.removeAll { $0.id == item.id }
        if cover == .generation(item) {
            cover = nil
        }

        Task { [weak self, dependencies] in
            do {
                try await dependencies.deleteGeneration(item)
            } catch {
                guard let self else { return }
                libraryItems = previousItems
                report(failure: String(localized: "Couldn’t delete this generation"))
            }
        }
    }

    /// «Save» на просмотре — это фотоплёнка. На сервере генерация лежит с
    /// момента создания, отдельной ручки «сохранить» у backend нет, и раньше
    /// кнопка молча не делала ничего: ни файла, ни запроса прав, ни ответа.
    func saveGeneration(_ item: LibraryItem) {
        guard !isSavingGeneration else { return }
        isSavingGeneration = true

        Task { [weak self, dependencies] in
            defer { self?.isSavingGeneration = false }
            do {
                try await dependencies.saveToPhotos.save(item)
                self?.toast = .copied(String(localized: "Saved to your photos"))
                self?.savedGenerationID = item.id
                try? await Task.sleep(for: .seconds(2))
                if self?.savedGenerationID == item.id {
                    self?.savedGenerationID = nil
                }
            } catch PhotoLibrarySaver.Failure.notAuthorized {
                // Отказ в правах — не сбой сохранения: подсказываем, где включить.
                self?.report(failure: String(localized: "Allow photo access in Settings to save generations"))
            } catch {
                self?.report(failure: String(localized: "Couldn’t save to your photos"))
            }
        }
    }

    // MARK: Голосовой ввод

    /// Начинает диктовку: спрашивает права, поднимает микрофон, запускает таймер.
    ///
    /// Состояние ставится **до** первого `await`: иначе между нажатием и появлением
    /// дорожки звука экран выглядит так, будто кнопка не сработала.
    func startVoiceInput() {
        guard voice == nil else { return }
        voice = VoiceInputState()
        dictationStartedAt = Date()

        transcriptionTask = Task { [weak self] in
            guard let self else { return }

            if let failure = await dictation.requestAuthorization() {
                voice = nil
                dictationStartedAt = nil
                permissionFailure = Self.message(for: failure)
                return
            }
            guard !Task.isCancelled, voice != nil else { return }

            do {
                try dictation.start { [weak self] update in
                    self?.applyDictation(update)
                }
            } catch {
                voice = nil
                dictationStartedAt = nil
                permissionFailure = Self.message(for: (error as? SpeechDictation.Failure) ?? .audioEngineFailed)
                return
            }

            startDictationTicker()
        }
    }

    /// Отмена: запись выбрасывается, поле ввода не трогается.
    func cancelVoiceInput() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        stopDictationTicker()
        dictation.cancel()
        voice = nil
    }

    /// Подтверждение: запись останавливается, распознанное дописывается в поле ввода.
    ///
    /// Именно дописывается, а не заменяет: пользователь мог что-то набрать руками
    /// и продиктовать продолжение.
    func confirmVoiceInput() {
        guard voice?.isTranscribing == false else { return }
        voice?.isTranscribing = true
        stopDictationTicker()

        let recognized = dictation.finish()

        transcriptionTask = Task { [weak self] in
            // Хвост распознавания приходит уже после остановки микрофона —
            // короткая пауза даёт ему дойти.
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }

            let text = voice?.transcript.isEmpty == false ? voice!.transcript : recognized
            append(dictated: text)
            dictation.cancel()
            voice = nil
        }
    }

    private func applyDictation(_ update: SpeechDictation.Update) {
        guard voice != nil else { return }
        if !update.transcript.isEmpty {
            voice?.transcript = update.transcript
        }
        // Дорожка в макете — 44 столбика: держим окно последних значений.
        var levels = voice?.levels ?? []
        levels.append(update.level)
        if levels.count > Self.waveformSampleCount {
            levels.removeFirst(levels.count - Self.waveformSampleCount)
        }
        voice?.levels = levels
    }

    private func append(dictated text: String) {
        let recognized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recognized.isEmpty else { return }
        draft = draft.isEmpty ? recognized : draft + " " + recognized
    }

    private func startDictationTicker() {
        dictationTicker?.cancel()
        dictationTicker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled, let startedAt = dictationStartedAt else { return }
                voice?.duration = .seconds(Int(Date().timeIntervalSince(startedAt)))
            }
        }
    }

    private func stopDictationTicker() {
        dictationTicker?.cancel()
        dictationTicker = nil
        dictationStartedAt = nil
    }

    private static let waveformSampleCount = 44

    private static func message(for failure: SpeechDictation.Failure) -> String {
        switch failure {
        case .microphoneDenied:
            String(localized: "Turn on microphone access in Settings to dictate a message.")
        case .recognitionDenied:
            String(localized: "Turn on speech recognition in Settings to dictate a message.")
        case .recognizerUnavailable:
            String(localized: "Speech recognition isn’t available for your language right now.")
        case .audioEngineFailed:
            String(localized: "Couldn’t start recording. Try again.")
        }
    }

    // MARK: Генерация изображения и видео

    /// Ждёт готовую генерацию и кладёт её в тот же пузырь ответа, что и текст.
    ///
    /// У сервера сессии чата для генерации нет — задача уходит в `/v1/media/*`,
    /// а не в `/v1/chats`, — поэтому переписку заводит сам репозиторий и
    /// пишет в `GenerationArchive`, лоадером ещё до готового результата: так
    /// её видно в истории сразу, а не только после выхода из чата.
    private func produceGeneration(
        for id: ChatMessage.ID,
        prompt: String,
        kind: LibraryItem.Kind,
        chatID: ChatSummary.ID?,
        model: AIModel,
        settings: GenerationSettings,
        attachments: [ChatAttachment],
        generation: Int
    ) async {
        defer {
            if generationID == generation {
                isGenerating = false
                isSearchingWeb = false
                isGeneratingMedia = false
                generationTask = nil
            }
        }

        do {
            let reply = try await dependencies.generateMedia(
                prompt: prompt,
                chatID: chatID,
                model: model,
                kind: kind,
                settings: settings,
                referenceImages: attachments
            )
            guard !Task.isCancelled, let index = messages.firstIndex(where: { $0.id == id }) else { return }

            adoptConversation(id: reply.chatID, title: reply.chatTitle)
            messages[index].generation = reply.message.generation
            messages[index].status = .complete
            // Новая генерация должна быть видна в библиотеке сразу, а не после
            // следующего холодного старта: список туда приходит с сервера.
            if let item = reply.message.generation {
                libraryItems.insert(item, at: 0)
            }
            await promptForReviewIfNeeded()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }

            switch error {
            case let ChatError.outOfTokens(chatID):
                // Кредитов не хватило — пузырь с ошибкой здесь лишний: баннер
                // уже объясняет, почему картинки нет, и ведёт за пакетом.
                if let chatID {
                    adoptConversation(id: chatID, title: nil)
                }
                notice = .tokensExhausted
                removePlaceholder(id)
            case let ChatError.generationFailed(chatID):
                // Переписка уже лежит в архиве с ошибкой на месте плейсхолдера —
                // подхватываем её здесь же, а не только при следующем открытии
                // истории.
                if let chatID {
                    adoptConversation(id: chatID, title: nil)
                }
                markFailed(id)
            default:
                markFailed(id)
            }
        }
    }

    // MARK: Генерация ответа

    private func produceReply(
        for id: ChatMessage.ID,
        text: String,
        attachments: [ChatAttachment],
        chatID: ChatSummary.ID?,
        modelID: AIModel.ID,
        mode: ChatMode,
        generation: Int,
        userMessageIndex: Int
    ) async {
        // Флаг снимается на любом выходе, включая ранний `guard`: иначе одна
        // потерявшаяся задача блокирует отправку навсегда. Но только если с тех пор
        // не началась новая генерация — иначе отменённая задача выключит кнопку «стоп»
        // у той, что ещё работает.
        defer {
            if generationID == generation {
                isGenerating = false
                isSearchingWeb = false
                generationTask = nil
            }
        }

        do {
            let reply = try await dependencies.sendMessage(
                message: text,
                attachments: attachments,
                chatID: chatID,
                modelID: modelID,
                mode: mode
            )
            guard !Task.isCancelled, let index = messages.firstIndex(where: { $0.id == id }) else { return }

            // Сервер называет разговор первым сообщением, но в ответе на
            // отправку заголовка нет — подставляем то же самое сами, иначе до
            // первого открытия меню и чат, и список зовутся «New Chat».
            adoptConversation(id: reply.chatID, title: reply.chatTitle ?? Self.title(from: text))
            if !attachments.isEmpty, userMessageIndex >= 0 {
                sentAttachments[reply.chatID, default: [:]][userMessageIndex] = attachments
            }
            messages[index].text = reply.message.text
            messages[index].generation = reply.message.generation
            messages[index].sources = reply.message.sources
            messages[index].status = .complete
            await promptForReviewIfNeeded()
        } catch is CancellationError {
            // Отмена — не ошибка: состояние приводит в порядок `stop()`.
            return
        } catch {
            // Отмену `URLSession` бросает не `CancellationError`, а своей ошибкой,
            // поэтому проверка нужна здесь: без неё баннер отменённого запроса
            // всплывает уже в другом, только что открытом чате.
            guard !Task.isCancelled else { return }

            switch error {
            case let ChatError.outOfTokens(chatID):
                // Сервер завёл разговор, даже если сам ответ заблокирован —
                // не подхватить этот id здесь значит отправить следующее
                // сообщение без chatID и завести ещё один разговор вместо
                // повтора в этом же.
                if let chatID {
                    adoptConversation(id: chatID, title: nil)
                }
                notice = .tokensExhausted
                // Баннер уже объясняет, почему ответа нет — красный пузырь
                // «failed» рядом с ним читался бы как вторая, другая ошибка,
                // а «Retry» на нём всё равно упёрся бы в тот же лимит.
                removePlaceholder(id)
            case let ChatError.dailyLimitReached(chatID):
                if let chatID {
                    adoptConversation(id: chatID, title: nil)
                }
                removePlaceholder(id)
                // Пробное сообщение одно: банер с кнопкой Upgrade — лишний тап
                // между отказом и пейволом. Открываем пейвол сразу.
                openPaywall(.subscription)
            case let ChatError.generationFailed(chatID):
                if let chatID {
                    adoptConversation(id: chatID, title: nil)
                }
                markFailed(id)
            default:
                markFailed(id)
            }
        }
    }

    /// Просьба оценить — после первого успешного ответа и один раз за установку:
    /// целевое действие состоялось, оценивать уже есть что. Правило и отметка
    /// живут в `RateUsPolicy`, здесь только показ.
    ///
    /// Тот же попап, что у ручной строки «Rate app» в настройках
    /// (`RateUsPopup` поверх сцены), а не полноэкранный `RateUsScreen` —
    /// последний слишком тяжёл для автоматического, ничем не спрошенного
    /// момента и держится за отдельный сид `rate-us` только ради сверки
    /// с макетом.
    private func promptForReviewIfNeeded() async {
        // Поверх открытого окна не поднимаем: UIKit не презентует с контроллера,
        // который сам уже презентует, — просьба просто не появилась бы.
        guard cover == nil, sheet == nil,
              await dependencies.rateUsPolicy.shouldPrompt(isSubscribed: balance != .upgrade)
        else {
            return
        }
        present(.rateUsPrompt)
    }

    /// Перечитывает список переписок с сервера.
    ///
    /// Локальные записи, которых в ответе ещё нет, остаются наверху: сервер
    /// может не успеть показать только что заведённый разговор, а пропадающая
    /// из списка переписка читается как потеря.
    private func refreshChats() async {
        guard let loaded = try? await dependencies.loadChats() else { return }
        let known = Set(loaded.map(\.id))
        chats = chats.filter { !known.contains($0.id) } + loaded
        if let currentChatID, let title = loaded.first(where: { $0.id == currentChatID })?.title {
            chatTitle = title
        }
    }

    /// Переписка, которую завёл сервер, становится текущей: без этого чат не попадёт
    /// ни в список, ни под переименование, а следующее сообщение заведёт ещё одну.
    private func adoptConversation(id: ChatSummary.ID, title: String?) {
        currentChatID = id
        if let title, chatTitle == Self.newChatTitle {
            chatTitle = title
        }
        if !chats.contains(where: { $0.id == id }) {
            chats.insert(ChatSummary(id: id, title: chatTitle), at: 0)
        }
    }

    /// Заголовок из первого сообщения — ровно так же его строит сервер.
    /// У сообщения из одних вложений текста нет, и заголовок остаётся прежним.
    private static func title(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func report(failure: String) {
        actionFailure = failure
    }

    /// Пустая заглушка ответа, который так и не начал печататься, — не пузырь,
    /// а состояние ожидания. Тот же случай, что уже обрабатывает `stop()`.
    private func removePlaceholder(_ id: ChatMessage.ID) {
        messages.removeAll { $0.id == id }
    }

    private func markFailed(_ id: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].status = .failed
        messages[index].text = ""
    }
}

/// Какой пейвол показывать.
enum PaywallKind: Hashable, Identifiable {
    case subscription
    case tokens
    case specialOffer

    var id: Self {
        self
    }

    /// Та же витрина на языке слоя приложения — ему про экраны знать незачем.
    var surface: PaywallCatalog.Surface {
        switch self {
        case .subscription: .subscription
        case .tokens: .tokens
        case .specialOffer: .specialOffer
        }
    }
}

/// Полноэкранные окна поверх основного экрана.
///
/// Меню сюда не входит: оно не модальное окно, а слой того же экрана — см.
/// `SideMenuContainer`.
enum MainSceneCover: Hashable, Identifiable {
    case paywall(PaywallKind)
    case rateUs
    case generation(LibraryItem)
    case aiConsent

    var id: Self {
        self
    }
}

/// Шторки снизу.
enum MainSceneSheet: Hashable, Identifiable {
    case attachments
    case appUpdate
    case currentPlan
    case generationSettings
    case rateUsPrompt

    var id: Self {
        self
    }
}

/// Экраны, которые открываются из меню.
enum MenuRoute: Hashable {
    case history
    case library
    case settings
}
