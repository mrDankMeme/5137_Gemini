import SwiftUI

/// Переписка: шапка с названием чата, лента сообщений и поле ввода.
struct ChatScreen: View {
    let title: String
    let messages: [ChatMessage]
    /// Черновик ответа — из модели, как и на главном экране: см. `HomeScreen`.
    @Binding var reply: String
    /// История выбранного чата ещё грузится: лента пуста не потому, что чат пуст.
    var isLoadingHistory = false
    var notice: ChatNoticeBanner.Kind?
    var isGenerating = false
    var isSearchingWeb = false
    var voice: VoiceInputState?

    let onOpenMenu: () -> Void
    let onNewChat: () -> Void
    let onSend: (String) -> Void
    let onStop: () -> Void
    let onRetry: (ChatMessage.ID) -> Void
    let onAttach: () -> Void
    /// У моделей изображений и видео вместо тумблера поиска в поле ввода стоит
    /// вход в параметры генерации — как и на главном экране. Без этого выбранная
    /// модель в переписке теряется: настройки открыть неоткуда, а глобус
    /// предлагает искать в интернете то, что модель рисует.
    var showsGenerationSettings = false
    var onOpenGenerationSettings: () -> Void = {}
    let onVoice: () -> Void
    let onCancelVoice: () -> Void
    let onConfirmVoice: () -> Void
    let onOpenGeneration: (LibraryItem) -> Void
    let onNoticeAction: () -> Void
    var attachments: [ChatAttachment] = []
    var onRemoveAttachment: (ChatAttachment) -> Void = { _ in }
    @Binding var mode: ChatMode
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onCopy: (String) -> Void
    let onShareMessage: (String) -> Void

    @State private var isActionsPresented = false
    @State private var isRenamePresented = false
    @State private var isDeletePresented = false
    @State private var draftTitle = ""
    /// Ширина ленты меряется один раз на уровне экрана: она не зависит от высоты
    /// содержимого, поэтому замер не зацикливается — в отличие от замера
    /// внутри самой карточки.
    @State private var contentWidth: CGFloat = 0
    /// Фокус поля ввода держит экран: по тапу мимо композера клавиатуру
    /// надо убрать, а изнутри `PromptBar` это состояние снаружи не достать.
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Тап мимо композера убирает клавиатуру. Слоем фона, а не жестом на
        // всём экране: так кнопки, ссылки и выделение текста в ленте забирают
        // тап себе, а до этого слоя доходит только пустое место.
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { isFocused = false }
        }
        .background {
            AccentGlow(
                size: CGSize(width: 622, height: 560),
                blur: 160,
                offset: CGSize(width: 0, height: 480)
            )
            .ignoresSafeArea()
        }
        .background(AppColor.bgPrimary)
    }

    private var header: some View {
        // В макете это название переписки, а не заголовок экрана: 14 pt regular.
        ScreenHeader(title: title, titleStyle: AppFont.caption) {
            CircleIconButton(
                systemImage: "text.alignleft",
                accessibilityLabel: "Menu",
                action: onOpenMenu
            )
        } trailing: {
            CircleIconButton(
                systemImage: "ellipsis",
                accessibilityLabel: "Chat actions",
                action: { isActionsPresented = true }
            )
            // Диалог висит на самой кнопке, а не на шапке: с iOS 26 он всплывает
            // у того вью, к которому привязан, и с шапки якорем оказывался её
            // центр — меню выходило посреди экрана со стрелкой в пустоту.
            // `Text(verbatim:)`, иначе компилятор вытаскивает пустую строку
            // в каталог отдельным ключом «».
            .confirmationDialog(
                Text(verbatim: ""),
                isPresented: $isActionsPresented,
                titleVisibility: .hidden
            ) {
                Button("Rename chat") {
                    draftTitle = title
                    isRenamePresented = true
                }
                Button("New Chat", action: onNewChat)
                Button("Delete chat", role: .destructive) { isDeletePresented = true }
                Button("Cancel", role: .cancel) {}
            }
        }
        // Оба диалога — из макета, вместе с текстами.
        .alert("Rename chat", isPresented: $isRenamePresented) {
            TextField("Enter a new name", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                let name = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                onRename(name)
            }
        } message: {
            Text("Enter a new name")
        }
        .alert("Delete this Chat?", isPresented: $isDeletePresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("You will not be able to restore it after deleting it.")
        }
    }

    @ViewBuilder
    private var conversation: some View {
        if isLoadingHistory, messages.isEmpty {
            // Показывать пустую ленту под названием чата нельзя: она читается
            // как «переписка пуста», хотя сообщения ещё летят.
            SparkleLoader()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading chat")
        } else {
            messageList
        }
    }

    private var messageList: some View {
        ScrollViewReader { scroll in
            scrollableMessages(scroll)
        }
    }

    /// Прокрутка к последнему сообщению делается явно, а не одним
    /// `defaultScrollAnchor(.bottom, for: .sizeChanges)`: содержимое лежит
    /// в `LazyVStack`, высота ещё не созданных строк системе неизвестна, и
    /// якорь не срабатывал — отправленное сообщение и приходящий ответ
    /// оставались ниже экрана, пока их не долистаешь рукой.
    private func scrollableMessages(_ scroll: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(messages) { message in
                    switch message.author {
                    case .user:
                        UserMessageBubble(message: message)
                    case .assistant:
                        AssistantMessageView(
                            message: message,
                            contentWidth: contentWidth,
                            isSearchingWeb: isSearchingWeb,
                            onRetry: { onRetry(message.id) },
                            onOpenGeneration: { if let item = message.generation { onOpenGeneration(item) } },
                            onCopy: { onCopy(message.text) },
                            onShare: { onShareMessage(message.text) }
                        )
                    }
                }
            }
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.bottom, Spacing.reg)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width - AppMetrics.screenPadding * 2
        } action: { contentWidth = max(0, $0) }
        // Короткая переписка начинается сверху, как в макете, но лента продолжает
        // липнуть к низу, когда приходит новое сообщение. Один только
        // `.defaultScrollAnchor(.bottom)` прижимал бы к низу и пару реплик.
        .defaultScrollAnchor(.top, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        // Тап по ленте тоже убирает клавиатуру. `ScrollView` забирает нажатия
        // на всей своей площади, поэтому слой под экраном до них не доходит, а
        // `simultaneousGesture` не отбирает тап у кнопок под ответом.
        .simultaneousGesture(TapGesture().onEnded { isFocused = false })
        // Новое сообщение: прыжок вниз с анимацией.
        .onChange(of: messages.last?.id) { _, id in
            guard let id else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                scroll.scrollTo(id, anchor: .bottom)
            }
        }
        // Ответ приходит по частям и растёт вниз. Держим низ в кадре, пока идёт
        // генерация, и без анимации: анимировать каждую порцию текста — дёрганно.
        .onChange(of: messages.last?.text) { _, _ in
            guard isGenerating, let id = messages.last?.id else { return }
            scroll.scrollTo(id, anchor: .bottom)
        }
    }

    private var composer: some View {
        VStack(spacing: Spacing.sm) {
            if let notice {
                ChatNoticeBanner(kind: notice, action: onNoticeAction)
            }

            PromptComposer(
                text: $reply,
                placeholder: String(localized: "Reply..."),
                voice: voice,
                isGenerating: isGenerating,
                onAttach: onAttach,
                onVoice: onVoice,
                onSend: send,
                onStop: onStop,
                onCancelVoice: onCancelVoice,
                onConfirmVoice: onConfirmVoice,
                showsGenerationSettings: showsGenerationSettings,
                onOpenGenerationSettings: onOpenGenerationSettings,
                mode: $mode,
                attachments: attachments,
                onRemoveAttachment: onRemoveAttachment,
                isFocused: $isFocused
            )
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.top, Spacing.sm)
        // Зазор снизу: без него поле упирается прямо в клавиатуру — системный
        // keyboard avoidance двигает блок вверх, но воздуха сам не даёт.
        .padding(.bottom, AppMetrics.composerBottomGap)
    }

    private func send() {
        // Текст стирается только если отправка действительно уходит. Раньше поле
        // очищалось до вызова, и отклонённое сообщение пропадало вместе с набранным.
        let message = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        // Как и на главном: с одним вложением и пустым полем отправка валидна,
        // кнопка активна — значит и обработчик обязан пропускать.
        guard !message.isEmpty || !attachments.isEmpty, !isGenerating else { return }
        onSend(message)
    }
}

#Preview("Ответ") {
    @Previewable @State var reply = ""
    @Previewable @State var mode: ChatMode = .general

    ChatScreen(
        title: "Healthy breakfast idea",
        messages: PreviewData.conversation,
        reply: $reply,
        onOpenMenu: {}, onNewChat: {}, onSend: { _ in }, onStop: {},
        onRetry: { _ in }, onAttach: {}, onVoice: {}, onCancelVoice: {}, onConfirmVoice: {},
        onOpenGeneration: { _ in }, onNoticeAction: {}, mode: $mode,
        onRename: { _ in }, onDelete: {}, onCopy: { _ in }, onShareMessage: { _ in }
    )
}

#Preview("Кончились токены") {
    @Previewable @State var reply = ""
    @Previewable @State var mode: ChatMode = .general

    ChatScreen(
        title: "Healthy breakfast idea",
        messages: Array(PreviewData.conversation.prefix(1)),
        reply: $reply,
        notice: .tokensExhausted,
        onOpenMenu: {}, onNewChat: {}, onSend: { _ in }, onStop: {},
        onRetry: { _ in }, onAttach: {}, onVoice: {}, onCancelVoice: {}, onConfirmVoice: {},
        onOpenGeneration: { _ in }, onNoticeAction: {}, mode: $mode,
        onRename: { _ in }, onDelete: {}, onCopy: { _ in }, onShareMessage: { _ in }
    )
}
