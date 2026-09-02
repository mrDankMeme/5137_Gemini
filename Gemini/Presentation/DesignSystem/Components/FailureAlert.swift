import SwiftUI

extension View {
    /// Системный алерт об отказе действия.
    ///
    /// Записи выполняются оптимистично, поэтому отказ обязан быть виден: молча
    /// «удавшееся» удаление, после которого объект возвращается, читается как
    /// поломка приложения. Текст очищается при закрытии — иначе повторный отказ
    /// с тем же сообщением уже не покажется.
    func failureAlert(_ message: Binding<String?>) -> some View {
        alert(
            message.wrappedValue ?? "",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        }
    }
}
