import SwiftUI

/// Поиск по чатам.
struct ChatHistoryScreen: View {
    let chats: [ChatSummary]
    let onBack: () -> Void
    let onSelectChat: (ChatSummary) -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [ChatSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return chats }
        return chats.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            BackHeader(title: String(localized: "Chat History"), onBack: onBack)

            searchField
                .padding(.horizontal, AppMetrics.screenPadding)

            // Пустой список и пустой результат поиска — разные ситуации,
            // и подсказка у них тоже разная.
            if chats.isEmpty {
                EmptyStateView(
                    title: "No chats yet",
                    message: "Start a conversation to see it here"
                )
            } else if results.isEmpty {
                EmptyStateView(title: "Nothing found", message: "Try a different search")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(results) { chat in
                            ChatRow(chat: chat) { onSelectChat(chat) }
                        }
                    }
                    .padding(.horizontal, AppMetrics.screenPadding)
                    .padding(.top, Spacing.reg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        // В макете поиск открывается с курсором и клавиатурой.
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.xs) {
            TextField("Search...", text: $query)
                .appTextStyle(AppFont.input)
                .foregroundStyle(AppColor.textPrimary)
                .tint(AppColor.caret)
                .submitLabel(.search)
                .focused($isSearchFocused)

            Image(systemName: "magnifyingglass")
                .font(AppFont.Icon.regular)
                .foregroundStyle(AppColor.textPrimary)
                .frame(width: AppMetrics.icon, height: AppMetrics.icon)
        }
        .padding(.horizontal, Spacing.reg)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.md))
    }

}

#Preview {
    ChatHistoryScreen(chats: PreviewData.chats, onBack: {}, onSelectChat: { _ in })
}
