import SwiftUI

/// Шторка выбора вложения: камера, галерея, файлы.
///
/// Первое обращение к камере и галерее вызывает системный запрос доступа —
/// в макете это отмечено отдельной заметкой дизайнера.
struct AttachmentSheet: View {
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onFiles: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            option("camera", title: "Camera", action: onCamera)
            option("photo", title: "Photos", action: onPhotos)
            // `doc.text`, а не `doc`: в макете у `icon/24/document2` лист
            // с текстовыми строками, а не пустой.
            option("doc.text", title: "Files", action: onFiles)
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.top, 38)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppColor.bgPrimary)
        // Высота шторки из макета — 192 pt вместе с полоской захвата.
        .presentationDetents([.height(AppMetrics.attachmentSheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.bgPrimary)
    }

    // `LocalizedStringKey`, а не `String`: `Text(String)` берёт перегрузку без
    // локализации, и подписи «Camera / Photos / Files» оставались английскими.
    private func option(_ systemImage: String, title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxxs) {
                Image(systemName: systemImage)
                    // Кегли из макета: камера и фото по 16, документ крупнее — 24.
                    .font(systemImage == "doc.text" ? AppFont.Icon.display : AppFont.Icon.medium)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(height: AppMetrics.icon)

                Text(title)
                    .appTextStyle(AppFont.caption)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.attachmentSourceTile)
            .background(AppColor.bgSecondary, in: .rect(cornerRadius: AppMetrics.badgeRadius))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AttachmentSheet(onCamera: {}, onPhotos: {}, onFiles: {})
    }
}
