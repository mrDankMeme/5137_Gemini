import SwiftUI

/// Библиотека сохранённых генераций: сетка два в ряд, у видео — кнопка проигрывания.
struct LibraryScreen: View {
    let items: [LibraryItem]
    let onBack: () -> Void
    let onSelect: (LibraryItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: String(localized: "Library"), onBack: onBack)

            if items.isEmpty {
                EmptyStateView(
                    title: "Nothing here yet",
                    message: "Saved photos and videos will show up here"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items) { item in
                            LibraryTile(item: item) { onSelect(item) }
                        }
                    }
                    .padding(.horizontal, AppMetrics.screenPadding)
                    .padding(.bottom, Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
    }

}

/// Плитка библиотеки. Пока файла нет, показывается ровная заглушка того же размера,
/// чтобы сетка не прыгала, когда подключится загрузка.
private struct LibraryTile: View {
    let item: LibraryItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GenerationPreview(item: item)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.sm))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryScreen(items: PreviewData.libraryItems, onBack: {}, onSelect: { _ in })
}
