import SwiftUI

/// Верхний арт пейволов и экрана оценки: свечение и картинка над ним.
///
/// Во всех трёх местах приём одинаковый, менялись только размер свечения
/// и отступ картинки — поэтому вынесено в один компонент.
///
/// Ставится **фоном**, а не слоем стека: картинка крупнее экрана задала бы
/// ширину контейнера и вытолкнула бы контент за края.
///
/// Два правила, за каждым — след в вёрстке:
///
/// 1. Свечение **не обрезается**. В макете это самостоятельный слой: эллипс
///    622 pt с размытием 300 уходит далеко за картинку и гаснет уже под заголовком.
///    Обрезка по высоте картинки давала ровную горизонтальную линию поперёк экрана,
///    на которой синий фон обрывался в чёрный — самая заметная непохожесть на макет.
///    Ниже свечение гасит градиент нижнего блока (`bottomScrim`), как в Figma.
/// 2. Центр свечения задаётся **от верха экрана**, а не смещением от картинки.
///    Высота картинки зависит от пропорций ассета, поэтому «сместить на N»
///    попадало в разные точки на разных экранах.
struct TopArtwork: View {
    let imageName: String
    /// Размер эллипса из макета.
    var glowSize: CGSize = CGSize(width: 622, height: 453)
    /// Расстояние от верха экрана до **центра** эллипса — как в макете.
    let glowCenterY: CGFloat
    /// Отступ картинки от верха экрана.
    var imageTopPadding: CGFloat = 30
    /// Арт стоит в стеке над содержимым и отдаёт ему место, а не лежит фоном.
    ///
    /// Нужно там, где содержимое переменной высоты: количество продуктов задаёт
    /// Adapty, фильтровать их платформа запрещает. Фоном арт в раскладке не
    /// участвует, поэтому лишняя карточка тарифа наезжала прямо на картинку —
    /// у пейвола токенов на пятом пакете заголовок оказывался поверх монет.
    var fitsAvailableSpace = false

    var body: some View {
        ZStack(alignment: .top) {
            // Нулевая высота: слой не участвует в раскладке, и центр эллипса
            // оказывается ровно на `glowCenterY` от верха экрана.
            AccentGlow(size: glowSize, blur: AppMetrics.artworkGlowBlur, opacity: 0.8)
                .frame(height: 0)
                .offset(y: glowCenterY)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .padding(.top, imageTopPadding)
                .frame(maxHeight: fitsAvailableSpace ? .infinity : nil, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        // Высота по картинке — только когда арт лежит фоном. В стеке он обязан
        // ужиматься, иначе `fixedSize` не даст отдать место содержимому.
        .modifier(NaturalHeight(isEnabled: !fitsAvailableSpace))
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }
}

/// `fixedSize` включается условно: применить его через `if` внутри `body`
/// нельзя — ветки дали бы разные типы вью.
private struct NaturalHeight: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }
}
