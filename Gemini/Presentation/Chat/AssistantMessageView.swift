import SwiftUI

/// Ответ ассистента. Без пузыря — в макете он лежит прямо на фоне, во всю ширину.
///
/// Три состояния из макета: ожидание (искра-лоадер), готовый markdown-ответ
/// и ошибка — красный пузырь с кнопкой повтора.
/// Готовая генерация внутри переписки: карточка со скруглением 32,
/// у видео — кнопка проигрывания поверх.
private struct GenerationCard: View {
    let item: LibraryItem
    let width: CGFloat
    let onOpen: () -> Void

    /// Пропорции карточки из макета: 330×442.
    private static let ratio: CGFloat = 442.0 / 330.0

    var body: some View {
        Button(action: onOpen) {
            GenerationPreview(item: item)
                .frame(width: width, height: width * Self.ratio)
                .clipShape(.rect(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.kind == .video ? "Generated video" : "Generated image")
    }
}

struct AssistantMessageView: View {
    let message: ChatMessage
    /// Ширина ленты. Нужна карточке генерации: внутри вертикального `ScrollView`
    /// высота не предлагается, и посчитать её из пропорций без ширины нельзя.
    let contentWidth: CGFloat
    /// Ответ ищет в интернете — лоадер подписывает, чем занят: поиск заметно
    /// дольше обычного ответа, и молчащая искра читается как зависание.
    var isSearchingWeb = false
    let onRetry: () -> Void
    let onOpenGeneration: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void

    var body: some View {
        switch message.status {
        case .inProgress where message.text.isEmpty:
            HStack(spacing: Spacing.xs) {
                SparkleLoader()
                if isSearchingWeb {
                    Text("Searching the web\u{2026}")
                        .appTextStyle(AppFont.reply)
                        .foregroundStyle(AppColor.textTertiary)
                }
                Spacer()
            }

        case .failed:
            failure

        case .inProgress, .complete:
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !message.text.isEmpty {
                    MarkdownText(text: message.text)
                }

                // Ширина ленты известна только со второго прохода раскладки:
                // до этого карточка схлопнулась бы в полоску и прыгнула.
                if let generation = message.generation, contentWidth > 0 {
                    GenerationCard(
                        item: generation,
                        width: contentWidth,
                        onOpen: onOpenGeneration
                    )
                }

                if !message.sources.isEmpty {
                    MessageSourcesRow(sources: message.sources)
                }

                // Действия появляются только у дописанного ответа: пока он печатается,
                // копировать и перегенерировать нечего.
                if message.status == .complete {
                    AssistantActionsRow(
                        onCopy: onCopy,
                        onShare: onShare,
                        onRegenerate: onRetry
                    )
                }
            }
        }
    }

    private var failure: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Вторая ветка — обычная строка с сервера, поэтому весь тернарник
            // выводился в `String`, а `Text(String)` не локализуется.
            Text(message.text.isEmpty
                ? String(localized: "Failed to generate the response.\nPlease try again.")
                : message.text)
                .appTextStyle(AppFont.body)
                .foregroundStyle(AppColor.error)
                .padding(.horizontal, Spacing.reg)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .strokeBorder(AppColor.error, lineWidth: 1)
                )

            Button(action: onRetry) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(AppFont.Icon.medium)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
