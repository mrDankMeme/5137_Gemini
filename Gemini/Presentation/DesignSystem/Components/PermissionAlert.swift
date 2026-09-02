import SwiftUI

extension View {
    /// Алерт об отказе в системном разрешении.
    ///
    /// Отличается от обычной ошибки тем, что пользователь **не может** ничего
    /// исправить в приложении: и микрофон, и распознавание речи переключаются
    /// только в настройках iOS, поэтому у алерта есть кнопка туда.
    func permissionAlert(_ message: Binding<String?>, openSettings: @escaping () -> Void) -> some View {
        alert(
            "Permission needed",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("Open Settings") {
                message.wrappedValue = nil
                openSettings()
            }
            Button("Not Now", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
