import SwiftUI

/// Круглая кнопка с иконкой: гамбургер и «…» в шапке, плюс и микрофон в поле ввода.
///
/// В макете таких две по размеру — 44 pt в навбаре и 36 pt в поле ввода,
/// поэтому размер и заливка задаются снаружи.
struct CircleIconButton: View {
    let systemImage: String
    /// `LocalizedStringKey`: подпись читает VoiceOver, и по-русски она должна
    /// звучать по-русски. Через `String` строка не попадала в каталог.
    let accessibilityLabel: LocalizedStringKey
    var size: CGFloat = 44
    /// Кегль глифа. Если не задан, берётся из токенов по размеру кнопки.
    var glyph: Font?
    var background: Color? = AppColor.bgSecondary
    var foreground: Color = AppColor.textPrimary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(glyph ?? AppFont.Icon.glyph(for: systemImage, buttonSize: size))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background {
                    if let background {
                        Circle().fill(background)
                    }
                }
                // Круг остаётся размером из макета, а нажимается всегда не меньше
                // 44 pt: иначе у кнопок 36 pt зона попадания меньше нормы Apple.
                .frame(width: max(size, 44), height: max(size, 44))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel)
    }
}
