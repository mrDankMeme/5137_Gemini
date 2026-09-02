import SwiftUI

/// Боковое меню. В макете это отдельный полноэкранный экран, а не выдвижная шторка.
struct MenuScreen: View {
    let chats: [ChatSummary]
    let balance: ProButton.Content

    let onClose: () -> Void
    let onNewChat: () -> Void
    let onSearchChats: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void
    /// См. `HomeScreen.onOpenBalance`.
    let onOpenBalance: () -> Void
    let onSelectChat: (ChatSummary) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Fenuko Flow") {
                ProButton(content: balance, action: onOpenBalance)
            } trailing: {
                CircleIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Close menu",
                    action: onClose
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    actions
                    recent
                }
                .padding(.horizontal, AppMetrics.screenPadding)
                // Кнопка настроек лежит поверх списка, поэтому оставляем под неё место.
                .padding(.bottom, 76)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        .overlay(alignment: .bottom) {
            // Под кнопкой настроек — градиент, иначе строки списка проезжают
            // под ней неприкрытыми.
            LinearGradient(
                colors: [AppColor.bgPrimary.opacity(0), AppColor.bgPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: AppMetrics.menuScrimHeight)
            .allowsHitTesting(false)
            .overlay(alignment: .bottomTrailing) {
                CircleIconButton(
                    systemImage: "gearshape",
                    accessibilityLabel: "Settings",
                    action: onOpenSettings
                )
                .padding(AppMetrics.screenPadding)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            MenuRow(title: "New Chat", systemImage: "pencil.line", action: onNewChat)
            MenuRow(title: "Search Chats", systemImage: "magnifyingglass", action: onSearchChats)
            MenuRow(title: "Library", systemImage: "folder", action: onOpenLibrary)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Заголовок «Recent» без списка выглядел бы обрывком.
            if !chats.isEmpty {
                Text("Recent")
                    .appTextStyle(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(chats) { chat in
                        ChatRow(chat: chat) { onSelectChat(chat) }
                    }
                }
            }
        }
    }
}

/// Пункт меню с иконкой.
private struct MenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    // 16, как в макете у pensil / search / folder.
                    .font(AppFont.Icon.medium)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(width: AppMetrics.icon, height: AppMetrics.icon)

                Text(title)
                    .appTextStyle(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.textPrimary)

                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: AppMetrics.menuRow)
            .contentShape(.rect)
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

/// Нажатая строка меню подсвечивается подложкой — так в макете.
private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? AppColor.bgSecondary : .clear,
                in: .rect(cornerRadius: Radius.reg)
            )
    }
}

/// Строка чата в списке.
struct ChatRow: View {
    let chat: ChatSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(chat.title)
                    .appTextStyle(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: AppMetrics.menuRow)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuScreen(
        chats: PreviewData.chats,
        balance: .upgrade,
        onClose: {}, onNewChat: {}, onSearchChats: {}, onOpenLibrary: {},
        onOpenSettings: {}, onOpenBalance: {}, onSelectChat: { _ in }
    )
}
