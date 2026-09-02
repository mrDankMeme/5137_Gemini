import SwiftUI

/// Короткое подтверждение действия, которое иначе никак себя не выдаёт.
///
/// Копирование — ровно такой случай: буфер обмена невидим, и без подтверждения
/// непонятно, сработала кнопка или палец промахнулся мимо иконки. Шторка
/// «Поделиться» и перегенерация в подтверждении не нуждаются — они видны сами.
///
/// В макете тоста нет: он собран по дизайн-системе — та же приподнятая подложка
/// и те же кегли, что у остальных плашек. Появится макет — сверить.
struct ToastMessage: Equatable {
    let icon: String
    let text: String

    static func copied(_ text: String) -> ToastMessage {
        ToastMessage(icon: "checkmark", text: text)
    }
}

/// Показать тост из любого вложенного вью, не протаскивая колбэк через три экрана.
struct ShowToastAction {
    let handler: (ToastMessage) -> Void

    func callAsFunction(_ message: ToastMessage) {
        handler(message)
    }
}

extension EnvironmentValues {
    @Entry var showToast = ShowToastAction { _ in }
}

extension View {
    /// Вешается один раз на корень сцены: тост обязан всплывать поверх меню,
    /// шторок и полноэкранных окон, а не внутри того экрана, который его позвал.
    func toastLayer(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastLayer(message: message))
    }
}

private struct ToastLayer: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    ToastView(message: message)
                        // Ниже шапки, а не поверх неё: на 16 pt плашка вставала
                        // ровно на название чата и читалась как его подмена.
                        .padding(.top, AppMetrics.tapTarget + AppMetrics.screenPadding * 2)
                        // Тост ничего не перехватывает: под ним продолжают
                        // нажиматься кнопки экрана.
                        .allowsHitTesting(false)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .motionAwareAnimation(.easeOut(duration: 0.2), value: message)
            // `task(id:)` перезапускается на каждом новом тосте, поэтому второе
            // копирование продлевает показ, а не гасит его по таймеру первого.
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                message = nil
            }
    }
}

private struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: message.icon)
                .font(AppFont.Icon.footnote)

            Text(message.text)
                .appTextStyle(AppFont.caption)
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(.horizontal, AppMetrics.screenPadding)
        .frame(minHeight: AppMetrics.tapTarget)
        .background(.ultraThinMaterial, in: .capsule)
        .background(AppColor.bgElevatedStrong, in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .accessibilityAddTraits(.isStaticText)
    }
}
