import SwiftUI
import UIKit

/// Прикреплённые файлы над полем ввода — до отправки сообщения.
///
/// В макете это ряд карточек 100×100 с шагом 4: скруглённая подложка `Bg/secondary`,
/// иконка 32 (или индикатор, пока файл загружается), имя файла 11 pt в две строки
/// и крестик удаления в правом верхнем углу.
struct ComposerAttachments: View {
    let attachments: [ChatAttachment]
    let onRemove: (ChatAttachment) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xxs) {
                ForEach(attachments) { attachment in
                    card(for: attachment)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: AppMetrics.attachmentCard)
    }

    @ViewBuilder
    private func card(for attachment: ChatAttachment) -> some View {
        // У снимка в макете карточка — сам снимок (заливка картинкой поверх
        // белых 10%), без подписи; у файла — подложка `Bg/secondary` с иконкой
        // и именем. Пока файл грузится, поверх снимка лежит чёрная 20%
        // и лоадер, иначе индикатор теряется на светлой фотографии.
        if case .image = attachment.kind, let image = photo(attachment) {
            Color.white.opacity(0.1)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .overlay {
                    if attachment.isUploading {
                        AppColor.uploadScrim.overlay { SparkleLoader(size: 32) }
                    }
                }
                .frame(width: AppMetrics.attachmentCard, height: AppMetrics.attachmentCard)
                .clipShape(.rect(cornerRadius: Radius.sm))
                .overlay(alignment: .topTrailing) { removeButton(for: attachment) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(name(for: attachment.kind))
        } else {
            labelledCard(for: attachment)
        }
    }

    private func photo(_ attachment: ChatAttachment) -> UIImage? {
        attachment.payload.flatMap(UIImage.init(data:))
    }

    private func labelledCard(for attachment: ChatAttachment) -> some View {
        VStack(spacing: Spacing.xs) {
            if attachment.isUploading {
                SparkleLoader(size: 32)
            } else {
                icon(for: attachment.kind)
            }

            Text(name(for: attachment.kind))
                .appTextStyle(AppFont.attachmentName)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: AppMetrics.attachmentLabelWidth)
        }
        .frame(width: AppMetrics.attachmentCard, height: AppMetrics.attachmentCard)
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.sm))
        .overlay(alignment: .topTrailing) { removeButton(for: attachment) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name(for: attachment.kind))
    }

    private func removeButton(for attachment: ChatAttachment) -> some View {
        Button {
            onRemove(attachment)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(AppFont.Icon.large)
                .foregroundStyle(AppColor.textPrimary)
                // Крестик в макете 24 pt, но нажимается область 44 pt.
                .frame(width: AppMetrics.icon, height: AppMetrics.icon)
                .frame(width: AppMetrics.tapTarget, height: AppMetrics.tapTarget, alignment: .topTrailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.xxs)
        .padding(.trailing, Spacing.xxs)
        .accessibilityLabel("Remove \(name(for: attachment.kind))")
    }

    @ViewBuilder
    private func icon(for kind: ChatAttachment.Kind) -> some View {
        switch kind {
        case .image:
            Image(systemName: "photo")
                .font(AppFont.Icon.display)
                .foregroundStyle(AppColor.textPrimary)
                .frame(height: AppMetrics.attachmentIcon)
        case .document:
            // Контурный лист со строками, как `icon/24/document2` в макете.
            Image(systemName: "doc.text")
                .font(AppFont.Icon.display)
                .foregroundStyle(AppColor.textPrimary)
                .frame(height: AppMetrics.attachmentIcon)
        }
    }

    private func name(for kind: ChatAttachment.Kind) -> String {
        switch kind {
        case .image: String(localized: "Photo")
        case let .document(name): name
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ComposerAttachments(
            attachments: [
                ChatAttachment(id: "1", kind: .document(name: "Meal-Plan.JSX"), isUploading: true),
                ChatAttachment(id: "2", kind: .document(name: "Hotel Reservation.pdf")),
                ChatAttachment(id: "3", kind: .image)
            ],
            onRemove: { _ in }
        )
        .padding(.horizontal, AppMetrics.screenPadding)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.bgPrimary)
}
