import SwiftUI

/// Синее свечение из макета: эллипс `Accent/primary` с сильным размытием.
///
/// В Figma это отдельный слой `Ellipse 6` на splash, онбординге, пейволах и главном
/// экране — везде один приём, меняются только размер и смещение. Рисуем формой,
/// а не картинкой: свечение остаётся чистым на любом экране и не тянет мегабайты PNG.
///
/// Важно: эллипс шире экрана (в макете 622 pt), поэтому вью **не должен** влиять
/// на раскладку. Иначе он распирает родительский стек, и соседние элементы
/// уезжают за края экрана. Ради этого основа — гибкий `Color.clear`,
/// а сам эллипс лежит в `overlay` и спокойно вылезает за границы.
struct AccentGlow: View {
    /// Размер эллипса в точках макета.
    var size: CGSize = CGSize(width: 622, height: 560)
    /// Радиус размытия.
    var blur: CGFloat = 150
    /// Смещение центра относительно контейнера.
    var offset: CGSize = .zero
    /// Плотность свечения. Размытие в SwiftUI растекается шире, чем layer blur
    /// в Figma, поэтому у верхнего арта плотность приглушена — иначе фон выходит
    /// заметно светлее макета, а углы у статус-бара подсинивают.
    var opacity: Double = 1

    var body: some View {
        Color.clear
            .overlay {
                Ellipse()
                    .fill(AppColor.accent.opacity(opacity))
                    .frame(width: size.width, height: size.height)
                    .blur(radius: blur)
                    .offset(x: offset.width, y: offset.height)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        AppColor.bgPrimary
        AccentGlow()
    }
    .ignoresSafeArea()
}
