import SwiftUI
import UIKit

/// Пузырь сообщения пользователя: прижат вправо, тёмная подложка со скруглением 32.
///
/// Ширина ограничена 322 pt, как в макете: длинный текст не растягивается
/// на весь экран и переписка читается.
struct UserMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 48)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if !message.attachments.isEmpty {
                    AttachmentStrip(attachments: message.attachments)
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .appTextStyle(AppFont.input)
                        .foregroundStyle(AppColor.textPrimary)
                        // Свой запрос тоже нужно уметь выделить: из него часто
                        // копируют кусок, чтобы переспросить иначе.
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.reg)
            // Подложка рисуется ДО ограничения ширины, иначе она растягивается
            // на все 322 pt и короткий запрос выглядит пузырём во весь экран.
            // Ограничение стоит после: оно задаёт, где переносится длинный текст,
            // и прижимает пузырь к правому краю.
            .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
            )
            .frame(maxWidth: AppMetrics.bubbleMaxWidth, alignment: .trailing)
            // На весь пузырь, а не только на текст: долгое нажатие рядом
            // с текстом, по подложке, тоже должно предложить копирование.
            .contextMenu {
                if !message.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your message: \(message.text)")
    }
}

/// Вложения внутри пузыря: плитки 100×100 — миниатюра фото или иконка документа
/// с именем файла под ней, как в макете.
private struct AttachmentStrip: View {
    let attachments: [ChatAttachment]

    /// Больше трёх плиток в пузырь не помещается, поэтому остаток сворачивается
    /// в «+N files» — так в макете.
    private static let visibleLimit = 3

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(attachments.prefix(Self.visibleLimit)) { attachment in
                tile(for: attachment)
            }

            if attachments.count > Self.visibleLimit {
                let hidden = attachments.count - Self.visibleLimit
                Text("\(hidden)+ files")
                    .appTextStyle(AppFont.captionMedium)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: AppMetrics.attachmentCard, height: AppMetrics.attachmentCard)
                    .background(AppColor.bgPrimary, in: .rect(cornerRadius: Radius.sm))
                    .accessibilityLabel("\(hidden) more files")
            }
        }
    }

    @ViewBuilder
    private func tile(for attachment: ChatAttachment) -> some View {
        switch attachment.kind {
        case .image:
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(AppColor.strokePrimary)
                .frame(width: AppMetrics.attachmentCard, height: AppMetrics.attachmentCard)
                .accessibilityElement()
                .overlay {
                    // Сам снимок, как в макете: там у плитки заливка картинкой.
                    // Заглушка остаётся запасным вариантом — для вложения,
                    // которое пришло без данных или не читается как изображение.
                    if let payload = attachment.payload, let image = UIImage(data: payload) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(AppFont.Icon.display)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.sm, style: .continuous))
                .accessibilityLabel("Image")

        case let .document(name):
            VStack(spacing: Spacing.xs) {
                // Контурный лист со строками, как `icon/24/document2` в макете.
                Image(systemName: "doc.text")
                    .font(AppFont.Icon.display)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: AppMetrics.attachmentIcon, height: AppMetrics.attachmentIcon)

                Text(name)
                    .appTextStyle(AppFont.attachmentName)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: AppMetrics.attachmentCard, height: AppMetrics.attachmentCard)
            .background(AppColor.bgPrimary, in: .rect(cornerRadius: Radius.sm))
            .accessibilityLabel("Document \(name)")
        }
    }
}
