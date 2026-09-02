import SwiftUI

/// Ряд действий под готовым ответом и дисклеймер под ним.
///
/// В макете это последний блок ответа: три иконки по 24 pt с шагом 12
/// и строка «AI can make mistakes — verify its answers» 11 pt цветом `Text/white 50`.
struct AssistantActionsRow: View {
    let onCopy: () -> Void
    let onShare: () -> Void
    let onRegenerate: () -> Void

    /// Копирование — единственное действие ряда, которое ничем себя не выдаёт:
    /// шторка «Поделиться» и перегенерация видны сами. Без галочки непонятно,
    /// сработала кнопка или промах мимо иконки.
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                action(isCopied ? "checkmark" : "doc.on.doc", label: "Copy", run: copy)
                action("square.and.arrow.up", label: "Share", run: onShare)
                action("arrow.trianglehead.2.clockwise.rotate.90", label: "Regenerate", run: onRegenerate)
            }
            // Ячейка шире иконки — в ней прячется зона нажатия. В макете
            // иконка стоит заподлицо с краем ответа, поэтому невидимый
            // припуск слева снимаем.
            .padding(.leading, -(AppMetrics.assistantActionStep - AppMetrics.icon) / 2)

            Text("AI can make mistakes — verify its answers")
                .appTextStyle(AppFont.disclaimer)
                .foregroundStyle(AppColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isCopied)
    }

    private func copy() {
        onCopy()
        withAnimation(.easeOut(duration: 0.15)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.15)) { isCopied = false }
        }
    }

    // `LocalizedStringKey`, а не `String`: у `accessibilityLabel` есть перегрузка
    // для обычной строки, и она ничего не переводит — VoiceOver читал бы
    // «Share» на русском устройстве.
    private func action(_ systemImage: String, label: LocalizedStringKey, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: systemImage)
                .font(AppFont.Icon.medium)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(AppColor.textPrimary)
                // Видимая иконка — 24 pt, как в макете, а нажимается вся ячейка
                // шириной 36 и высотой 44. Раньше ячейки были по 44 и наезжали
                // друг на друга отрицательным шагом: соседняя иконка перехватывала
                // нажатия, и «Copy» с «Share» отзывались не там, где нарисованы.
                .frame(width: AppMetrics.icon, height: AppMetrics.icon)
                .frame(width: AppMetrics.assistantActionStep, height: AppMetrics.tapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
