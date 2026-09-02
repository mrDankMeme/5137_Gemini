import SwiftUI

/// Главный экран: шапка с выбором модели, приветствие с подсказками и поле ввода.
///
/// Это состояние «пустого» чата. Как только пользователь отправляет сообщение,
/// экран сменяется перепиской — приветствие и подсказки при этом исчезают.
struct HomeScreen: View {
    /// Черновик живёт в модели: диктовка пишет в то же поле, а экран под ней
    /// меняется на чат — локальный `@State` терял бы набранное.
    @Binding var prompt: String

    let balance: ProButton.Content
    let models: [AIModel]
    let selectedModelID: AIModel.ID
    @Binding var isModelPickerPresented: Bool
    /// Не `nil`, пока идёт диктовка: тогда вместо поля ввода показывается дорожка звука.
    var voice: VoiceInputState?
    /// Пока ответ уже запрошен, отправка и подсказки заблокированы.
    var isSending = false
    /// Каталог моделей пришёл. До этого модель не выбрана, и отправлять нечем:
    /// на первом кадре с настоящим backend экран живёт без единой модели.
    var isReady = true

    let onOpenMenu: () -> Void
    let onSelectModel: (AIModel) -> Void
    /// Нажатие на кнопку баланса в шапке. Не то же, что «оформить подписку»:
    /// куда вести, решает модель по тому, что на кнопке написано.
    let onOpenBalance: () -> Void
    let onSelectSuggestion: (SuggestedAction) -> Void
    let onSend: (String) -> Void
    let onAttach: () -> Void
    let onVoice: () -> Void
    let onCancelVoice: () -> Void
    let onConfirmVoice: () -> Void
    var showsGenerationSettings = false
    var onOpenGenerationSettings: () -> Void = {}
    @Binding var mode: ChatMode
    var attachments: [ChatAttachment] = []
    var onRemoveAttachment: (ChatAttachment) -> Void = { _ in }

    /// Фокус поля ввода держит экран: по тапу мимо композера клавиатуру
    /// надо убрать, а изнутри `PromptBar` это состояние снаружи не достать.
    @FocusState private var isFocused: Bool

    private var selectedModel: AIModel? {
        models.first { $0.id == selectedModelID }
    }

    private var modelTitle: String { selectedModel?.title ?? "" }

    /// Подсказка в поле ввода зависит от модели — так в макете для Imagen и Veo.
    /// В макете здесь опечатки («Craeate», «Dayly») — по решению команды пишем правильно.
    private var placeholder: String {
        switch selectedModel?.capability {
        case .image: String(localized: "Create an image of")
        case .video: String(localized: "Create a video of")
        default: String(localized: "Enter your prompt")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 0)
            greeting
                .padding(.horizontal, AppMetrics.screenPadding)
                .padding(.bottom, AppMetrics.homeGreetingCenteringInset)
            Spacer(minLength: 0)

            PromptComposer(
                text: $prompt,
                placeholder: placeholder,
                voice: voice,
                isSending: isSending,
                isReady: isReady,
                onAttach: onAttach,
                onVoice: onVoice,
                onSend: send,
                onCancelVoice: onCancelVoice,
                onConfirmVoice: onConfirmVoice,
                showsGenerationSettings: showsGenerationSettings,
                onOpenGenerationSettings: onOpenGenerationSettings,
                mode: $mode,
                attachments: attachments,
                onRemoveAttachment: onRemoveAttachment,
                isFocused: $isFocused
            )
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.top, Spacing.sm)
            // Зазор снизу: без него поле упирается прямо в клавиатуру — системный
            // keyboard avoidance двигает блок вверх, но воздуха сам не даёт.
            .padding(.bottom, AppMetrics.composerBottomGap)
            // Высоту делит `VStack`, и при нехватке места он выдавливает
            // содержимое за оба края. Приоритет отдаёт композеру его высоту
            // первым: ужаться должно приветствие, а не поле ввода.
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Анимация на всём экране, а не только на подсказках: с клавиатурой
        // подсказки исчезают, приветствие поднимается, поле ввода растёт —
        // это одно перестроение, и анимировать надо его целиком. Иначе чипы
        // гасли плавно, а приветствие прыгало рывком.
        //
        // Та же кривая и длительность, что у самого композера, — экран
        // переезжает одним движением.
        .motionAwareAnimation(.smooth(duration: 0.28), value: isFocused)
        // Тап мимо композера убирает клавиатуру. Слоем фона, а не жестом на
        // всём экране: так кнопки, ссылки и выделение текста в ленте забирают
        // тап себе, а до этого слоя доходит только пустое место.
        .background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { isFocused = false }
        }
        // Свечение именно фоном: как слой стека оно бы задало ширину контейнера
        // по своему эллипсу и вытолкнуло шапку с полем ввода за края экрана.
        .background {
            // Эллипс 622×560 лежит в макете на y=544, то есть центром на 824.
            // Смещение считается от центра экрана (874/2 = 437), отсюда 387.
            AccentGlow(
                size: CGSize(width: 622, height: 560),
                blur: 160,
                offset: CGSize(width: 0, height: AppMetrics.homeGlowCenterY - 437)
            )
            .ignoresSafeArea()
        }
        .background(AppColor.bgPrimary)
        .overlay(alignment: .top) { modelPicker }
    }

    private var header: some View {
        ScreenHeader {
            // Модель стоит ровно по центру экрана, а не между кнопками:
            // иначе она съезжает от разной ширины «Pro» и баланса токенов.
            // Пока каталог не пришёл, чип показывает заглушку: пустая пилюля
            // с одной стрелкой выглядит как поломка вёрстки.
            ModelChip(title: modelTitle.isEmpty ? String(localized: "Loading") : modelTitle) {
                withAnimation(.easeOut(duration: 0.15)) { isModelPickerPresented.toggle() }
            }
            .redacted(reason: modelTitle.isEmpty ? .placeholder : [])
            .disabled(models.isEmpty)
        } leading: {
            CircleIconButton(
                systemImage: "text.alignleft",
                accessibilityLabel: "Menu",
                action: onOpenMenu
            )
        } trailing: {
            ProButton(content: balance, action: onOpenBalance)
        }
        .zIndex(1)
    }

    /// Список моделей раскрывается под чипом. Под ним лежит прозрачный слой:
    /// без него нажатие мимо меню не закрывает его, а чипы под меню остаются нажимаемыми.
    @ViewBuilder
    private var modelPicker: some View {
        if isModelPickerPresented {
            ZStack(alignment: .top) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { isModelPickerPresented = false }
                    }

                ModelPickerMenu(models: models, selectedID: selectedModelID) { model in
                    withAnimation(.easeOut(duration: 0.15)) { isModelPickerPresented = false }
                    onSelectModel(model)
                }
                .padding(.top, 55)
            }
            .transition(.opacity)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var greeting: some View {
        VStack(spacing: Spacing.lg) {
            Text("Ready when you are.\nWhat\u{2019}s the plan?")
                .appTextStyle(AppFont.h3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textPrimary)
                // Приветствие не сжимается: с поднятой клавиатурой места
                // в обрез, и без этого SwiftUI отбирал высоту у него —
                // вторая строка пропадала, а первая обрывалась многоточием.
                // Ужиматься есть чему другому, см. приоритет у подсказок.
                .fixedSize(horizontal: false, vertical: true)

            // С поднятой клавиатурой подсказок в макете нет (`main--home-4`):
            // остаётся только приветствие над полем ввода.
            //
            // Гасим прозрачностью, а не `if`. Условие убирало чипы из раскладки,
            // блок менял высоту — и приветствие над ним прыгало на новое место
            // рывком, потому что своё перестроение мы анимируем своей кривой,
            // а подъём от клавиатуры система делает своей. Прозрачность
            // раскладку не трогает вовсе: двигает всё только клавиатура,
            // одним движением и своей анимацией.
            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(SuggestedAction.all) { action in
                    SuggestionChip(title: action.title, systemImage: action.systemImage) {
                        onSelectSuggestion(action)
                        // Текст подставлен — курсор сразу в поле, чтобы
                        // человек дописывал своё, а не искал, куда нажать.
                        isFocused = true
                    }
                }
            }
            .opacity(isFocused ? 0 : 1)
            // Высота схлопывается, а не блок удаляется. Удаление SwiftUI
            // не интерполирует — оно происходит скачком, и приветствие над
            // подсказками прыгало на новое место. Высота же интерполируется:
            // ряд гаснет и складывается одним движением, а места над
            // клавиатурой освобождается ровно столько, чтобы шапка осталась
            // на месте, а не уехала под статус-бар.
            .frame(maxHeight: isFocused ? 0 : nil, alignment: .top)
            .clipped()
            // Невидимые чипы нажимать нельзя, и VoiceOver их не читает.
            .disabled(isSending || !isReady || isFocused)
            .accessibilityHidden(isFocused)
        }
    }

    private func send() {
        // Поле чистит модель в `send(_:)`: она же владеет черновиком.
        let message = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        // Одно вложение без текста — валидная отправка, и кнопка в этом случае
        // активна. Проверять только текст значило бы: кнопка горит, палец
        // нажимает, не происходит ничего.
        guard !message.isEmpty || !attachments.isEmpty, !isSending, isReady else { return }
        onSend(message)
    }
}

/// Состояние диктовки, которое показывает поле ввода.
struct VoiceInputState: Equatable {
    var levels: [CGFloat] = []
    var duration: Duration = .zero
    var isTranscribing = false
    /// Распознанное на текущий момент. Копится, пока говорят, и уходит
    /// в поле ввода при подтверждении.
    var transcript = ""
}

#Preview("Без подписки") {
    @Previewable @State var picker = false
    @Previewable @State var prompt = ""
    @Previewable @State var mode: ChatMode = .general

    HomeScreen(
        prompt: $prompt,
        balance: .upgrade,
        models: PreviewData.models,
        selectedModelID: "gemini-2.5-flash",
        isModelPickerPresented: $picker,
        onOpenMenu: {}, onSelectModel: { _ in }, onOpenBalance: {},
        onSelectSuggestion: { _ in }, onSend: { _ in }, onAttach: {}, onVoice: {},
        onCancelVoice: {}, onConfirmVoice: {}, mode: $mode
    )
}

#Preview("Выбор модели") {
    @Previewable @State var picker = true
    @Previewable @State var prompt = ""
    @Previewable @State var mode: ChatMode = .general

    HomeScreen(
        prompt: $prompt,
        balance: .tokenBalance(500),
        models: PreviewData.models,
        selectedModelID: "gemini-2.5-flash",
        isModelPickerPresented: $picker,
        onOpenMenu: {}, onSelectModel: { _ in }, onOpenBalance: {},
        onSelectSuggestion: { _ in }, onSend: { _ in }, onAttach: {}, onVoice: {},
        onCancelVoice: {}, onConfirmVoice: {}, mode: $mode
    )
}
