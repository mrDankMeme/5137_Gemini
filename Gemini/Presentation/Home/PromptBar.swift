import SwiftUI

/// Поле ввода внизу экрана: вложения, текст, голос и отправка.
///
/// Кнопка отправки активна только когда есть что отправлять. Она сразу уходит
/// в `isSending` и блокируется — платформа требует не давать повторный тап
/// до результата.
struct PromptBar: View {
    @Binding var text: String
    var placeholder: String = String(localized: "Enter your prompt")
    var isSending: Bool = false
    /// Каталог моделей уже пришёл. До этого отправлять нельзя: запрос ушёл бы
    /// с пустым идентификатором модели, и backend отбил бы его.
    var isReady: Bool = true
    /// Пока ответ генерируется, кнопка отправки превращается в «стоп» — как в макете.
    var isGenerating: Bool = false
    let onAttach: () -> Void
    let onVoice: () -> Void
    let onSend: () -> Void
    var onStop: () -> Void = {}
    /// У моделей изображений и видео рядом с вложениями появляется вход
    /// в параметры генерации — так в макете для Imagen и Veo.
    var showsGenerationSettings = false
    var onOpenGenerationSettings: () -> Void = {}
    /// Режим ответа. Тумблера нет в макете: поиск в интернете добавлен после него,
    /// и включать его надо где-то, где пользователь видит это до отправки.
    @Binding var mode: ChatMode
    var attachments: [ChatAttachment] = []
    var onRemoveAttachment: (ChatAttachment) -> Void = { _ in }

    /// Фокус живёт на экране, а не здесь: снимать его нужно по тапу мимо поля,
    /// а достать `@FocusState` дочернего вью снаружи нельзя.
    @FocusState.Binding var isFocused: Bool

    /// Отправлять можно и один файл без текста — так работает вложение в чат.
    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && !isSending && isReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !attachments.isEmpty {
                ComposerAttachments(attachments: attachments, onRemove: onRemoveAttachment)
            }

            controls
                .padding(AppMetrics.composerPadding)
                .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
                )
                // Из макета: чёрная 25%, размытие 24 и сдвиг вниз 12. Радиус
                // вдвое меньше фигмовского — layer blur там примерно вдвое
                // крупнее гауссова, — а сдвиг переносится как есть, он в точках.
                .shadow(color: .black.opacity(0.25), radius: 12, y: 12)
        }
    }

    /// Включение поиска в интернете. Включённый режим виден по заливке кнопки —
    /// иначе неясно, уйдёт запрос с поиском или без, а стоит он дороже.
    private var webSearchToggle: some View {
        CircleIconButton(
            systemImage: "globe",
            accessibilityLabel: mode.searchesWeb ? "Web search on" : "Web search off",
            size: 36,
            background: mode.searchesWeb ? AppColor.accent : nil
        ) {
            mode = mode.searchesWeb ? .general : .research
        }
        .accessibilityAddTraits(mode.searchesWeb ? [.isButton, .isSelected] : .isButton)
    }

    /// Пустое поле — одна строка: «+», подсказка и кнопки в ряд (`main--home`).
    /// Появился текст — текст занимает свою строку во всю ширину, кнопки уходят
    /// под неё (`main--home-4`).
    ///
    /// Две раскладки над теми же тремя вью, переключаются через `AnyLayout`.
    ///
    /// Не одна раскладка с параметром: **свой `Layout` SwiftUI не анимирует** —
    /// параметр меняется, расстановка пересчитывается мгновенно, и серая
    /// подсказка прыгала на месте. `AnyLayout` система анимирует сама, вью
    /// переезжают, а не подменяются. И не две ветки во `ViewBuilder`: разные
    /// ветки считаются разными вью, дерево подменяется целиком.
    ///
    /// `geometryGroup` держит группу как целое, иначе части едут вразнобой.
    private var controls: some View {
        let layout = isExpanded
            ? AnyLayout(ComposerExpandedLayout(rowSpacing: AppMetrics.composerRowSpacing))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 8))

        return layout {
            leadingButtons

            textField
                .frame(minHeight: isExpanded
                    ? AppMetrics.composerLineHeight
                    : AppMetrics.compactButton)
                .padding(.horizontal, isExpanded ? 8 : AppMetrics.composerTextInset)
                .padding(.top, isExpanded ? 12 : 0)

            trailingButtons
        }
        .geometryGroup()
        .animation(.smooth(duration: 0.28), value: isExpanded)
    }

    /// Разворачивается по **фокусу**, а не по непустому тексту — как в образце.
    /// От текста раскладка менялась ровно в момент ввода первой буквы, и строка
    /// на глазах уезжала влево и вверх: SwiftUI одновременно и перекладывал
    /// поле, и перерисовывал его содержимое. Фокус меняется один раз, до ввода,
    /// поэтому переход виден целиком, а печать уже ничего не двигает.
    private var isExpanded: Bool {
        isFocused
    }

    /// Зазоры считаются по **видимым** кружкам, а не по зонам нажатия.
    /// У `CircleIconButton(size: 36)` зона раздута до 44 pt (норма Apple),
    /// то есть вокруг кружка по 4 pt невидимого припуска, и шаг стека даёт
    /// видимый зазор `8 + spacing`. В макете слева между «+» и слайдерами 8
    /// (`main--home-11`), значит шаг 0; справа между микрофоном и отправкой 4,
    /// значит шаг −4. Раньше стояло −4 и 4 — выходило 4 и 12.
    private var leadingButtons: some View {
        HStack(spacing: 0) {
            CircleIconButton(
                systemImage: "plus",
                accessibilityLabel: "Attach",
                size: 36,
                background: nil,
                action: onAttach
            )

            if showsGenerationSettings {
                CircleIconButton(
                    systemImage: "slider.horizontal.3",
                    accessibilityLabel: "Generation settings",
                    size: 36,
                    background: nil,
                    action: onOpenGenerationSettings
                )
            }

            // Поиск в интернете — режим ответа, а у генерации ответа нет:
            // модель рисует картинку, искать ей нечего. Заодно тумблер не
            // остаётся третьей кнопкой слева — с ним подсказка «Create an
            // image of» не помещается и обрывается на середине.
            if !showsGenerationSettings {
                webSearchToggle
            }
        }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        if isGenerating {
            CircleIconButton(
                systemImage: "stop.fill",
                accessibilityLabel: "Stop generating",
                size: 36,
                background: AppColor.strokeSecondary,
                action: onStop
            )
        } else {
            HStack(spacing: -4) {
                CircleIconButton(
                    systemImage: "mic",
                    accessibilityLabel: "Voice input",
                    size: 36,
                    background: nil,
                    action: onVoice
                )

                CircleIconButton(
                    systemImage: "arrow.up",
                    accessibilityLabel: "Send",
                    size: 36,
                    background: AppColor.accent,
                    isEnabled: canSend,
                    action: onSend
                )
            }
        }
    }

    private var textField: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .appTextStyle(AppFont.input)
            .foregroundStyle(AppColor.textPrimary)
            .tint(AppColor.accent)
            .lineLimit(1 ... 6)
            .focused($isFocused)
    }

}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var mode: ChatMode = .general
    @Previewable @FocusState var isFocused: Bool

    VStack {
        Spacer()
        PromptBar(text: $text, onAttach: {}, onVoice: {}, onSend: {}, mode: $mode, isFocused: $isFocused)
            .padding(.horizontal, AppMetrics.screenPadding)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
