import BroadExtensions
import SwiftUI
import UIKit

/// Основная часть приложения после проверки доступа.
///
/// Решает, что показать — пустой главный экран с подсказками или переписку, —
/// и держит все модальные окна на одном источнике правды `MainSceneCover`.
struct MainScene: View {
    @State private var model: MainSceneModel
    /// Политика, условия и форма поддержки открываются внутри приложения.
    /// Шторка вешается на сами экраны, а не на корень сцены: пейволы
    /// показываются полноэкранным окном, и шторка с корня оказалась бы под ним.
    @State private var policyLink: URL?
    /// Готовое письмо в поддержку. Показывается системным редактором.
    @State private var supportMail: SupportMailData?

    let paywallCatalog: PaywallCatalog

    init(dependencies: MainSceneDependencies, paywallCatalog: PaywallCatalog) {
        _model = State(initialValue: MainSceneModel(dependencies: dependencies, paywallCatalog: paywallCatalog))
        self.paywallCatalog = paywallCatalog
    }

    @Environment(\.openURL) private var openURL

    var body: some View {
        sideMenu
            .task { await model.load() }
            // Стартовый пейвол закрывается до появления сцены, поэтому его отказ
            // отрабатывается здесь: пользователь попадает на главный экран, и
            // предложение всплывает следом.
            .task { await model.presentSpecialOfferIfEligible() }
            .motionAwareAnimation(.easeInOut(duration: 0.2), value: model.isConversationVisible)
            .overlay(alignment: .top) { banner }
            .fullScreenCover(item: $model.cover, content: cover)
            .sheet(item: $model.presentedSheet, content: sheet)
            // Просьба оценить — слой поверх сцены, а не шторка: в макете это
            // центрированный алерт, и с презентации не поднять системное окно
            // оценки, которое идёт следом за согласием.
            .overlay { rateAlert }
            // Без анимации на изменении состояния переход не проигрывается
            // вовсе — карточка возникала скачком.
            .motionAwareAnimation(.smooth(duration: 0.25), value: model.sheet == .rateUsPrompt)
            .sheet(item: $model.shareItem) { ShareSheet(items: $0.activityItems) }
            .sheet(item: $supportMail) { data in
                MailComposeView(
                    address: DevelopmentConfiguration.supportEmail,
                    data: data,
                    onFinish: { supportMail = nil }
                )
                .ignoresSafeArea()
            }
            .failureAlert($model.actionFailure)
            // Тост живёт на корне сцены: он обязан всплывать поверх меню,
            // шторок и полноэкранных окон.
            .toastLayer($model.toast)
            .environment(\.showToast, ShowToastAction { model.toast = $0 })
            .permissionAlert($model.permissionFailure, openSettings: openSystemSettings)
            .attachmentPickers(
                source: $model.attachmentSource,
                onPicked: { model.attach($0) },
                onFailure: { model.actionFailure = $0 }
            )
    }

    /// Меню во всю ширину: содержимое уезжает вправо целиком, на его место
    /// приходит меню. Закрывается свайпом влево и крестиком в шапке меню.
    private var sideMenu: some View {
        SideMenuContainer(
            // На вложенных экранах правый свайп принадлежит возврату назад:
            // два жеста на одно движение спорят и оба срабатывают через раз.
            isEnabled: model.menuPath.isEmpty,
            isExpanded: $model.isMenuOpen
        ) {
            menu
        } content: {
            navigation
        }
    }

    /// Основной экран и всё, что открывается из меню, — в одном стеке.
    private var navigation: some View {
        NavigationStack(path: $model.menuPath) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MenuRoute.self, destination: destination)
                // Свайп-назад возвращает платформа: UIKit гасит его вместе со
                // спрятанным навбаром, а все вложенные экраны рисуют свою шапку.
                // Свой мост был хуже — он не восстанавливал прежний делегат жеста.
                .broadInteractiveSwipeBack()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.isConversationVisible {
            HomeScreen(
                prompt: $model.draft,
                balance: model.balance,
                models: model.models,
                selectedModelID: model.selectedModelID,
                isModelPickerPresented: $model.isModelPickerPresented,
                voice: model.voice,
                isSending: model.isGenerating,
                // Пустой каталог моделей не должен запирать экран: сеть умеет
                // отправлять без модели (`model: nil`), и сервер берёт свою.
                // Раньше сбой `/v1/models` навсегда гасил чипы и кнопку отправки —
                // без сообщения и без повтора.
                isReady: true,
                onOpenMenu: { model.isMenuOpen = true },
                onSelectModel: { model.selectedModelID = $0.id },
                onOpenBalance: { model.openBalance() },
                onSelectSuggestion: { model.applySuggestion($0) },
                onSend: { model.send($0) },
                onAttach: { model.present(.attachments) },
                onVoice: { model.startVoiceInput() },
                onCancelVoice: { model.cancelVoiceInput() },
                onConfirmVoice: { model.confirmVoiceInput() },
                showsGenerationSettings: model.supportsGenerationSettings,
                onOpenGenerationSettings: { model.present(.generationSettings) },
                mode: $model.chatMode,
                attachments: model.pendingAttachments,
                onRemoveAttachment: { model.removeAttachment($0) }
            )
        } else {
            ChatScreen(
                title: model.chatTitle,
                messages: model.messages,
                reply: $model.draft,
                isLoadingHistory: model.isLoadingHistory,
                notice: model.notice,
                isGenerating: model.isGenerating,
                isSearchingWeb: model.isSearchingWeb,
                voice: model.voice,
                onOpenMenu: { model.isMenuOpen = true },
                onNewChat: { model.startNewChat() },
                onSend: { model.send($0) },
                onStop: { model.stop() },
                onRetry: { model.regenerate(messageID: $0) },
                onAttach: { model.present(.attachments) },
                showsGenerationSettings: model.supportsGenerationSettings,
                onOpenGenerationSettings: { model.present(.generationSettings) },
                onVoice: { model.startVoiceInput() },
                onCancelVoice: { model.cancelVoiceInput() },
                onConfirmVoice: { model.confirmVoiceInput() },
                onOpenGeneration: { model.cover = .generation($0) },
                onNoticeAction: { model.openPaywall(model.notice == .tokensExhausted ? .tokens : .subscription) },
                attachments: model.pendingAttachments,
                onRemoveAttachment: { model.removeAttachment($0) },
                mode: $model.chatMode,
                onRename: { model.rename(to: $0) },
                onDelete: { model.deleteCurrentChat() },
                onCopy: { model.copy($0, confirmation: String(localized: "Message copied")) },
                onShareMessage: { model.share($0) }
            )
        }
    }

    // MARK: Модальные окна

    /// Пишем в поддержку письмом с уже проставленной диагностикой. Нет
    /// настроенной почты — отдаём `mailto:` системе, его подхватит сторонний
    /// клиент; там же и остаётся выбор, чем открыть.
    private func contactSupport() {
        let data = SupportMail.make(
            accountID: model.accountID,
            balance: model.balanceDescription,
            isSubscribed: model.balance != .upgrade
        )
        guard SupportMail.canComposeInApp else {
            guard let url = SupportMail.mailtoURL(data, to: DevelopmentConfiguration.supportEmail) else {
                model.actionFailure = supportAddressHint
                return
            }
            // Почтового клиента может не быть вовсе — тогда система ссылку
            // не примет, и кнопка осталась бы немой. Показываем адрес, чтобы
            // человеку было куда написать.
            openURL(url) { accepted in
                if !accepted {
                    model.actionFailure = supportAddressHint
                }
            }
            return
        }
        supportMail = data
    }

    private var supportAddressHint: String {
        String(
            localized: "Write to us at \(DevelopmentConfiguration.supportEmail)",
            comment: "Показывается, если на устройстве нет почтового клиента"
        )
    }

    private func cover(_ route: MainSceneCover) -> some View {
        coverContent(route)
            // На самом окне, а не на корне сцены: корень под полноэкранным
            // окном, и шторка с него не показалась бы.
            .policyLinkSheet(url: $policyLink)
            // Та же причина: «поделиться» с просмотра генерации ждало, пока
            // окно закроют, и всплывало уже на пустом экране.
            .sheet(item: $model.shareItem) { ShareSheet(items: $0.activityItems) }
    }

    @ViewBuilder
    private func coverContent(_ route: MainSceneCover) -> some View {
        switch route {
        case let .paywall(kind):
            paywall(kind)
        case .rateUs:
            RateUsScreen(
                onContinue: {
                    model.cover = nil
                    ReviewAdapter.request()
                },
                onSkip: { model.cover = nil }
            )
        case let .generation(item):
            generationViewer(item, onBack: { model.cover = nil })
        case .aiConsent:
            AIConsentScreen(
                onAgree: { model.acceptAIConsent() },
                onDecline: { model.declineAIConsent() },
                onOpenPrivacyPolicy: { policyLink = DevelopmentConfiguration.privacyPolicyURL },
                onOpenTermsOfUse: { policyLink = DevelopmentConfiguration.termsOfUseURL },
                noticeText: model.hasDeclinedAIConsent
                    ? String(localized: "Sending a message needs your consent to AI data processing.")
                    : nil
            )
        }
    }

    private func generationViewer(_ item: LibraryItem, onBack: @escaping () -> Void) -> some View {
        GenerationViewerScreen(
            item: item,
            isSaving: model.isSavingGeneration,
            isSaved: model.savedGenerationID == item.id,
            isSharing: model.isPreparingShare,
            onBack: onBack,
            onSave: { model.saveGeneration(item) },
            onShare: { model.shareGeneration(item, text: DevelopmentConfiguration.shareMessage) },
            onRegenerate: model.canRegenerate(item) ? { model.regenerate(item) } : nil,
            onShowInChat: onBack,
            onDelete: { model.deleteGeneration(item) }
        )
    }

    @ViewBuilder
    private func sheet(_ route: MainSceneSheet) -> some View {
        switch route {
        case .attachments:
            // Источник запоминается, шторка закрывается, и пикер поднимается уже
            // с открытого экрана — иначе UIKit его не покажет.
            AttachmentSheet(
                onCamera: { pickAttachment(from: .camera) },
                onPhotos: { pickAttachment(from: .photos) },
                onFiles: { pickAttachment(from: .files) }
            )

        case .appUpdate:
            AppUpdateSheet(
                onUpdate: { closeSheet() },
                onSkip: { closeSheet() }
            )

        case .rateUsPrompt:
            // Сюда не попадает: `presentedSheet` его отфильтровывает, потому что
            // в макете это центрированный алерт и рисуется он слоем.
            EmptyView()

        case .currentPlan:
            CurrentPlanSheet(
                planName: model.currentPlanName ?? String(localized: "Free"),
                periodDescription: model.currentPlanPeriod,
                canCancel: model.currentPlanPeriod != nil || model.balance != .upgrade,
                onCancelSubscription: { closeSheet() }
            )
            .task { await model.refreshCurrentPlan() }

        case .generationSettings:
            GenerationSettingsSheet(
                includesVideoOptions: model.selectedModel?.capability == .video,
                showsResolution: !(model.selectedModel?.resolutions.isEmpty ?? true),
                settings: $model.generationSettings,
                onApply: { closeSheet() }
            )
        }
    }

    /// Содержимое ящика. Своего стека у него больше нет: экраны из меню
    /// полноэкранные и живут в основном стеке — внутри ящика им места нет.
    private var menu: some View {
        MenuScreen(
            chats: model.chats,
            balance: model.balance,
            onClose: { model.isMenuOpen = false },
            onNewChat: { model.startNewChat() },
            onSearchChats: { model.openFromMenu(.history) },
            onOpenLibrary: { model.openFromMenu(.library) },
            onOpenSettings: { model.openFromMenu(.settings) },
            onOpenBalance: { model.openBalance() },
            onSelectChat: { model.openChat($0) }
        )
    }

    /// Закрывает шторку выбора и открывает нужный пикер.
    private func pickAttachment(from source: AttachmentSource) {
        closeSheet()
        Task {
            // Пикер поднимается только после того, как шторка действительно ушла:
            // презентация «впритык» к закрытию теряется.
            try? await Task.sleep(for: .milliseconds(350))
            model.attachmentSource = source
        }
    }

    private func closeSheet() {
        model.sheet = nil
    }

    private func destination(for route: MenuRoute) -> some View {
        destinationContent(for: route)
            .policyLinkSheet(url: $policyLink)
    }

    @ViewBuilder
    private func destinationContent(for route: MenuRoute) -> some View {
        switch route {
        case .history:
            ChatHistoryScreen(
                chats: model.chats,
                onBack: {
                    if !model.menuPath.isEmpty {
                        model.menuPath.removeLast()
                    }
                },
                onSelectChat: { model.openChat($0) }
            )
            .toolbar(.hidden, for: .navigationBar)

        case .library:
            LibraryScreen(
                items: model.libraryItems,
                onBack: {
                    if !model.menuPath.isEmpty {
                        model.menuPath.removeLast()
                    }
                },
                onSelect: { model.openGeneration($0) }
            )
            .toolbar(.hidden, for: .navigationBar)

        case .settings:
            SettingsScreen(
                balance: model.balance,
                cacheSize: model.cacheSize,
                accountID: model.accountID,
                appVersion: model.appVersion,
                isRestoring: model.isRestoring,
                isClearingCache: model.isClearingCache,
                onBack: {
                    if !model.menuPath.isEmpty {
                        model.menuPath.removeLast()
                    }
                },
                onOpenPaywall: { model.openPaywall(.subscription) },
                onOpenBalance: { model.openBalance() },
                onRateApp: { model.present(.rateUsPrompt) },
                onShare: { model.share(DevelopmentConfiguration.shareMessage) },
                onClearCache: { Task { await model.clearCache() } },
                onRestorePurchases: { Task { await model.restorePurchases() } },
                onContactUs: { contactSupport() },
                onOpenPrivacyPolicy: { policyLink = DevelopmentConfiguration.privacyPolicyURL },
                onOpenUsagePolicy: { policyLink = DevelopmentConfiguration.termsOfUseURL },
                onOpenLanguage: { openSystemSettings() }
            )
            // Размер кеша считается при открытии экрана, а не на старте сцены:
            // обход каталога — дисковая работа, и к моменту показа число уже
            // успело бы устареть.
            .task { await model.refreshCacheSize() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Показ и закрытие пейвола уходят в Adapty: без этого у варианта
    /// A/B-теста нет просмотров, и сравнивать варианты не по чему.
    private func paywall(_ kind: PaywallKind, onClose: (() -> Void)? = nil) -> some View {
        paywallContent(kind, onClose: onClose)
            .task { await paywallCatalog.didAppear(kind.surface) }
            .onDisappear {
                Task { await paywallCatalog.didClose(kind.surface) }
            }
    }

    @ViewBuilder
    private func paywallContent(_ kind: PaywallKind, onClose: (() -> Void)? = nil) -> some View {
        let dismiss = onClose ?? { model.cover = nil }

        switch kind {
        case .subscription:
            ProPaywallScreen(
                plans: paywallCatalog.subscriptionPlans,
                bullets: [
                    String(localized: "Smart actions enabled"),
                    String(localized: "Image generation"),
                    String(localized: "Always ready to work"),
                ],
                isPurchasing: model.isPurchasing,
                isRestoring: model.isRestoring,
                isLoadingCatalog: !paywallCatalog.isLoaded,
                selectedIndex: $model.selectedPlanIndex,
                onContinue: {
                    Task {
                        if await model.purchaseSubscription() {
                            dismiss()
                        }
                    }
                },
                // Закрыли пейвол — предлагаем скидку. Правило дома: спецпредложение
                // всплывает именно после отказа, а не само по себе.
                onClose: {
                    dismiss()
                    Task { await model.presentSpecialOfferIfEligible() }
                },
                onRestore: {
                    Task {
                        if await model.restorePurchases() {
                            dismiss()
                        }
                    }
                },
                onOpenPrivacyPolicy: { policyLink = DevelopmentConfiguration.privacyPolicyURL },
                onOpenTermsOfUse: { policyLink = DevelopmentConfiguration.termsOfUseURL }
            )

        case .tokens:
            TokenPaywallScreen(
                packages: paywallCatalog.tokenPackages,
                isPurchasing: model.isPurchasing,
                isRestoring: model.isRestoring,
                selectedIndex: $model.selectedTokenPackageIndex,
                onContinue: {
                    Task {
                        if await model.purchaseTokenPackage() {
                            dismiss()
                        }
                    }
                },
                onClose: dismiss,
                onRestore: {
                    Task {
                        if await model.restorePurchases() {
                            dismiss()
                        }
                    }
                },
                onOpenPrivacyPolicy: { policyLink = DevelopmentConfiguration.privacyPolicyURL },
                onOpenTermsOfUse: { policyLink = DevelopmentConfiguration.termsOfUseURL }
            )

        case .specialOffer:
            if let offer = paywallCatalog.specialOffer {
                // Данные — из продукта Adapty, включая зачёркнутую цену: она обязана
                // быть настоящей ценой тарифа того же периода. Если предложения нет
                // или скидка не выходит, `specialOffer` пустой и экран не открывается.
                SpecialOfferScreen(
                    discountTitle: offer.discountTitle,
                    planName: offer.planName,
                    planPeriod: offer.planPeriod,
                    price: offer.price,
                    crossedPrice: offer.crossedPrice,
                    endsAt: model.specialOfferEndsAt,
                    onExpire: dismiss,
                    isPurchasing: model.isPurchasing,
                    isRestoring: model.isRestoring,
                    onContinue: {
                        Task {
                            if await model.purchaseSpecialOffer() {
                                dismiss()
                            }
                        }
                    },
                    onClose: dismiss,
                    onRestore: {
                        Task {
                            if await model.restorePurchases() {
                                dismiss()
                            }
                        }
                    },
                    onOpenPrivacyPolicy: { policyLink = DevelopmentConfiguration.privacyPolicyURL },
                    onOpenTermsOfUse: { policyLink = DevelopmentConfiguration.termsOfUseURL }
                )
            }
        }
    }

    /// Язык приложения меняется только в системных настройках — ведём туда.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    /// Просьба оценить приложение: слой поверх сцены, а не шторка.
    @ViewBuilder
    private var rateAlert: some View {
        if model.sheet == .rateUsPrompt {
            RateUsPopup(
                onRate: {
                    closeSheet()
                    ReviewAdapter.request()
                },
                onDismiss: { closeSheet() }
            )
            // Не голая прозрачность: карточка ещё и подрастает из 94 %.
            // Так она появляется мягко, а не возникает готовой — в 232
            // диалоги показываются так же.
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
    }

    /// Баннер о готовой генерации, когда пользователь в приложении.
    @ViewBuilder
    private var banner: some View {
        if model.isGenerationReadyBannerPresented {
            InAppNotificationBanner(
                title: String(localized: "The generations are ready!"),
                message: String(localized: "Check out the result now."),
                onTap: {
                    withAnimation { model.isGenerationReadyBannerPresented = false }
                    if let item = model.libraryItems.first {
                        model.cover = .generation(item)
                    }
                },
                onDismiss: {
                    withAnimation { model.isGenerationReadyBannerPresented = false }
                }
            )
            .zIndex(2)
            // Баннер уходит сам, как системное уведомление. Отмену не глотаем:
            // если баннер уже закрыли рукой, «таймер истёк» срабатывать не должен.
            .task {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    return
                }
                withAnimation { model.isGenerationReadyBannerPresented = false }
            }
        }
    }
}
