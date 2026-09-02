import SwiftUI

/// Согласие на обработку сообщений и файлов через ИИ.
///
/// Полноэкранный слой, а не шторка: то же решение, что у Rate Us, — здесь
/// это первое, что видит человек в приложении, и шторка поверх недописанного
/// сообщения читалась бы как мелкая помеха, а не как то, чему нужно уделить
/// внимание. Показывается один раз за установку, до первой отправки.
///
/// Текст и раскладка — по образцу 5121 (`AIDataConsentView`): абзац о том,
/// куда уходят данные, несёт настоящие ссылки на политики провайдеров —
/// у нас это OpenAI для переписки и fal.ai для генерации изображений и видео,
/// сверено с каталогом моделей backend. Одних слов «мы передаём ИИ-провайдеру»
/// недостаточно для App Review 5.1.1(i): нужно назвать получателя и дать
/// дотянуться до его политики, а не спрятать это за своей.
///
/// Флажок обязателен: кнопка активируется только после него, а не собирает
/// согласие сквозным тапом по «Agree».
struct AIConsentScreen: View {
    let onAgree: () -> Void
    let onDecline: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenTermsOfUse: () -> Void
    /// Показывается, если экран открылся снова после отказа — на этот раз
    /// потому что отправка сообщения без согласия не уходит.
    var noticeText: String?

    @State private var isChecked = false

    var body: some View {
        VStack(spacing: 0) {
            header
            // Только эта часть скроллится: кнопки внизу держатся на месте,
            // а плывёт содержимое над ними — не наоборот.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.reg) {
                    if let noticeText {
                        notice(noticeText)
                    }
                    paragraph("To chat or create with Fenuko Flow, you need to agree to how the content you send is shared.")
                    paragraph(Self.processingText)
                    paragraph("Your conversations are kept so you can return to them later. Deleting a chat removes its content from our servers.")
                    paragraph("Fenuko Flow never sells your data or uses it for advertising, tracking, profiling, or training AI models.")
                    legalRow
                }
                .padding(.horizontal, AppMetrics.screenPadding)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.lg)
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.bgPrimary)
    }

    private var header: some View {
        Text("AI Data Processing Consent")
            .appTextStyle(AppFont.h3)
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.top, AppMetrics.screenPadding)
            .padding(.bottom, Spacing.reg)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .appTextStyle(AppFont.footnoteMedium)
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.reg)
            .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.sm))
    }

    private func paragraph(_ text: String) -> some View {
        Text(markdown(text))
            .appTextStyle(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Абзац с переписчиками несёт inline-ссылки на политики провайдеров —
    /// сверено живым запросом к каталогу моделей backend: вся переписка
    /// на OpenAI, вся генерация изображений и видео (nano-banana, kling, veo) —
    /// на fal.ai.
    private static let processingText =
        "Fenuko Flow sends what you choose to submit — your messages and any " +
        "files you attach — to its own servers and to the AI provider " +
        "handling your request. Text conversations run on " +
        "[OpenAI](https://openai.com/policies/privacy-policy/); image and " +
        "video generation run on [fal.ai](https://fal.ai/legal/privacy-policy)."

    /// Ссылки на провайдеров выделены явно, а не оставлены на стандартный
    /// стиль ссылок: иначе на тёмном фоне они не отличались бы от обычного
    /// текста абзаца, а ревьюеру нужно видеть, что на политику получателя
    /// можно перейти, а не просто прочитать его название.
    private func markdown(_ text: String) -> AttributedString {
        guard var attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return AttributedString(text)
        }
        let linkRanges = attributed.runs.filter { $0.link != nil }.map(\.range)
        for range in linkRanges {
            attributed[range].foregroundColor = AppColor.accentLight
            attributed[range].underlineStyle = .single
        }
        return attributed
    }

    private var legalRow: some View {
        HStack(spacing: Spacing.reg) {
            Button("Privacy Policy", action: onOpenPrivacyPolicy)
            Button("Terms of Use", action: onOpenTermsOfUse)
        }
        .buttonStyle(.plain)
        .appTextStyle(AppFont.captionMedium)
        .foregroundStyle(AppColor.accentLight)
    }

    private var footer: some View {
        VStack(spacing: Spacing.reg) {
            checkbox
            HStack(spacing: Spacing.sm) {
                Button(action: onDecline) {
                    Text("Not Now")
                        .appTextStyle(AppFont.button)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: AppMetrics.secondaryButtonWidth)
                        .frame(height: AppMetrics.buttonHeight)
                        .background(AppColor.bgSecondary, in: .capsule)
                }
                .buttonStyle(.plain)

                // Флажок обязателен: согласие — осознанное действие, а не то,
                // что экран может собрать одним тапом насквозь.
                PrimaryButton(title: "Agree and Continue", isEnabled: isChecked, action: onAgree)
            }
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.top, Spacing.reg)
        .padding(.bottom, AppMetrics.screenPadding)
        .background(
            AppColor.bgPrimary
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColor.strokePrimary)
                        .frame(height: AppMetrics.hairline)
                }
        )
    }

    private var checkbox: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isChecked.toggle() }
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Неотмеченный флажок — то состояние, которое должно бросаться
                // в глаза: без своей заливки и яркой обводки он тонет в тёмном
                // фоне экрана, и непонятно, что тут вообще есть чекбокс.
                RoundedRectangle(cornerRadius: Spacing.xxs, style: .continuous)
                    .fill(isChecked ? AppColor.accent : AppColor.bgPrimary)
                    .frame(width: Spacing.xxl, height: Spacing.xxl)
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.xxs, style: .continuous)
                            .strokeBorder(
                                isChecked ? AppColor.accent : AppColor.strokeSecondary,
                                lineWidth: 1.5
                            )
                    )
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(AppFont.Icon.checkboxMark)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                    }

                Text("I agree that what I submit will be shared with Fenuko Flow and the relevant AI provider only to process my request.")
                    .appTextStyle(AppFont.footnote)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(Spacing.sm)
            .background(
                isChecked ? AppColor.accent.opacity(0.12) : AppColor.bgSecondary,
                in: .rect(cornerRadius: Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(isChecked ? AppColor.accent : AppColor.strokeSecondary, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    AIConsentScreen(onAgree: {}, onDecline: {}, onOpenPrivacyPolicy: {}, onOpenTermsOfUse: {})
}

#Preview("Reopened after decline") {
    AIConsentScreen(
        onAgree: {}, onDecline: {}, onOpenPrivacyPolicy: {}, onOpenTermsOfUse: {},
        noticeText: "Sending a message needs your consent to AI data processing."
    )
}
