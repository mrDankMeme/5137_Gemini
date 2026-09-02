import SwiftUI

/// Типографика из Figma: страница «🧱 design system: typography & colors».
///
/// Весь макет набран SF Pro — это системный шрифт iOS, поэтому подключать
/// файлы шрифтов и `BroadFontRegistrar` не нужно, хватает `Font.system`.
/// Во всех стилях трекинг равен −2% от кегля, а межстрочный задан в процентах;
/// `AppTextStyle` хранит и то и другое, чтобы `Text` можно было настроить одним модификатором.
struct AppTextStyle: Equatable, Sendable {
    let size: CGFloat
    let weight: Font.Weight
    /// Межстрочное расстояние из макета, в пунктах.
    let lineHeight: CGFloat
    let tracking: CGFloat
    /// Рисунок шрифта. Моноширинный нужен коду: в пропорциональном SF Pro
    /// отступы в листинге разъезжаются и таблицы в ответе перестают читаться.
    var design: Font.Design = .default

    var font: Font {
        .system(size: size, weight: weight, design: design)
    }

    /// Тот же стиль капителью — так набраны плашки выгоды и «Special Offer».
    var smallCapsFont: Font {
        font.smallCaps()
    }

    /// `lineSpacing` в SwiftUI — это зазор *между* строками, а не полная высота строки,
    /// поэтому вычитаем кегль. Отрицательный зазор SwiftUI не поддерживает.
    var lineSpacing: CGFloat {
        max(0, lineHeight - size)
    }
}

enum AppFont {
    /// H1 — SF Pro Medium 40 / 120%.
    static let h1 = AppTextStyle(size: 40, weight: .medium, lineHeight: 48, tracking: -0.8)
    /// h2 — SF Pro Bold 32 / 120%.
    static let h2 = AppTextStyle(size: 32, weight: .bold, lineHeight: 38.4, tracking: -0.64)
    /// h3 — SF Pro Medium 24 / 120%.
    static let h3 = AppTextStyle(size: 24, weight: .medium, lineHeight: 28.8, tracking: -0.48)
    /// h4 — SF Pro Semibold 18 / 120%.
    static let h4 = AppTextStyle(size: 18, weight: .semibold, lineHeight: 21.6, tracking: -0.36)
    /// input txt — SF Pro Regular 16 / 140%.
    static let input = AppTextStyle(size: 16, weight: .regular, lineHeight: 22.4, tracking: -0.32)
    /// Текст ответа ассистента — 16 / 160%. Отдельный стиль: в макете у переписки
    /// межстрочный заметно свободнее, чем у поля ввода.
    /// Вес — Light, как в макете: у текста ответа там SF Pro Light (274 по
    /// вариативной оси), и это не разовая настройка — 32 узла против 5 у Medium.
    static let reply = AppTextStyle(size: 16, weight: .light, lineHeight: 25.6, tracking: -0.32)
    /// Листинг кода в ответе. Моноширинный, кегль на два пункта мельче ответа:
    /// иначе строка кода не влезает в ширину переписки и всё уезжает в скролл.
    static let code = AppTextStyle(size: 14, weight: .regular, lineHeight: 20,
                                   tracking: 0, design: .monospaced)
    /// Язык над листингом — та же моноширинная гарнитура, но мельче и приглушённее.
    static let codeCaption = AppTextStyle(size: 12, weight: .medium, lineHeight: 16,
                                          tracking: 0, design: .monospaced)
    /// body (medium 16) — SF Pro Medium 16 / 120%.
    static let bodyMedium = AppTextStyle(size: 16, weight: .medium, lineHeight: 19.2, tracking: -0.32)
    /// body (regular 16) — SF Pro Regular 16 / 120%.
    static let body = AppTextStyle(size: 16, weight: .regular, lineHeight: 19.2, tracking: -0.32)
    /// btntxt — SF Pro Semibold 16 / 120%.
    static let button = AppTextStyle(size: 16, weight: .semibold, lineHeight: 19.2, tracking: -0.32)
    /// Строка настроек — SF Pro Regular 17 / 22. В макете у таблицы настроек
    /// свой кегль, крупнее общего `body`.
    static let row = AppTextStyle(size: 17, weight: .regular, lineHeight: 22, tracking: -0.4)
    /// Заголовок группы настроек — SF Pro Semibold 17 / 22.
    static let rowTitle = AppTextStyle(size: 17, weight: .semibold, lineHeight: 22, tracking: -0.4)
    /// Подпись под настройками — SF Pro Regular 13 / 18.
    static let footnoteSmall = AppTextStyle(size: 13, weight: .regular, lineHeight: 18, tracking: -0.26)
    /// Строка «подпись — значение» в шторке подписки — SF Pro Regular 16 / 20.
    static let rowValue = AppTextStyle(size: 16, weight: .regular, lineHeight: 20, tracking: -0.2)
    /// Цена в карточке тарифа — SF Pro Bold 16 / 20.8.
    static let price = AppTextStyle(size: 16, weight: .bold, lineHeight: 20.8, tracking: -0.2)
    /// Заголовок ин-апп баннера — SF Pro Semibold 15 / 17.
    static let bannerTitle = AppTextStyle(size: 15, weight: .semibold, lineHeight: 17, tracking: -0.2)
    /// Текст ин-апп баннера — SF Pro Regular 15 / 18.
    static let bannerMessage = AppTextStyle(size: 15, weight: .regular, lineHeight: 18, tracking: -0.2)
    /// body (medium 14) — SF Pro Medium 14 / 120%.
    static let captionMedium = AppTextStyle(size: 14, weight: .medium, lineHeight: 16.8, tracking: -0.28)
    /// regular 14 — SF Pro Regular 14 / 150%.
    static let caption = AppTextStyle(size: 14, weight: .regular, lineHeight: 21, tracking: -0.28)
    /// medium 13 — SF Pro Medium 13 / 130%.
    static let footnoteMedium = AppTextStyle(size: 13, weight: .medium, lineHeight: 16.9, tracking: -0.26)
    /// light 13 — SF Pro Light 13 / 130%.
    static let footnote = AppTextStyle(size: 13, weight: .light, lineHeight: 16.9, tracking: -0.26)

    // MARK: Стили отдельных экранов

    /// Дисклеймер под ответом ассистента — 11 / 14.3 Medium.
    static let disclaimer = AppTextStyle(size: 11, weight: .medium, lineHeight: 14.3, tracking: -0.2)
    /// Имя файла на карточке вложения — 11 / 13.2.
    static let attachmentName = AppTextStyle(size: 11, weight: .regular, lineHeight: 13.2, tracking: 0)
    /// Подпись под круглой кнопкой действия — 10 / 11.
    static let actionCaption = AppTextStyle(size: 10, weight: .regular, lineHeight: 11, tracking: -0.2)
    /// Заголовок баннера о лимите — 15 / 20 Semibold.
    static let noticeTitle = AppTextStyle(size: 15, weight: .semibold, lineHeight: 20, tracking: -0.2)
    /// Текст баннера о лимите — 14 / 20.
    static let noticeMessage = AppTextStyle(size: 14, weight: .regular, lineHeight: 20, tracking: -0.2)
    /// Надпись над отсчётом спецпредложения — 14 / 16.8 Semibold.
    static let countdownCaption = AppTextStyle(size: 14, weight: .semibold, lineHeight: 16.8, tracking: -0.3)
    /// Цифры отсчёта — 32 / 32 Bold.
    static let countdownValue = AppTextStyle(size: 32, weight: .bold, lineHeight: 32, tracking: -0.6)
    /// Надпись «Special Offer» — 32 / 41.6.
    static let offerEyebrow = AppTextStyle(size: 32, weight: .regular, lineHeight: 41.6, tracking: 0)
    /// Размер скидки — 72 / 93.6 Heavy.
    static let offerDiscount = AppTextStyle(size: 72, weight: .heavy, lineHeight: 93.6, tracking: -1.4)
    /// Цена в карточке спецпредложения — 20 / 26 Bold.
    static let offerPrice = AppTextStyle(size: 20, weight: .bold, lineHeight: 26, tracking: -0.2)

    // MARK: Иконки

    /// Кегли символов SF. Единственное место, где для иконок задаётся системный шрифт:
    /// правило платформы требует держать `Font.system` только в файле токенов.
    enum Icon {
        static let caption = Font.system(size: 10)
        static let small = Font.system(size: 12)
        static let footnote = Font.system(size: 13)
        /// Шеврон в строке настроек — 17 semibold, как в макете.
        static let chevron = Font.system(size: 17, weight: .semibold)
        static let compact = Font.system(size: 14)
        static let medium = Font.system(size: 16)
        static let regular = Font.system(size: 17)
        static let large = Font.system(size: 18)
        static let xLarge = Font.system(size: 20)
        static let huge = Font.system(size: 22)
        static let display = Font.system(size: 24)

        /// Строчный `code` внутри абзаца. Отдельно от `AppFont.code`: здесь нужен
        /// не стиль вью, а `Font` — им красится диапазон внутри `AttributedString`.
        static let inlineCode = Font.system(size: 15, weight: .regular, design: .monospaced)

        /// Галочка внутри самодельного чекбокса — экран согласия ИИ.
        static let checkboxMark = Font.system(size: 12, weight: .bold)

        /// Кегль глифа круглой кнопки.
        ///
        /// В макете он привязан к самой иконке, а не к размеру кнопки: у «плюса»
        /// 18, у микрофона и стрелки отправки 16, у гамбургера 16, а у «…» и
        /// «назад» — 18, хотя все три кнопки по 44. Прежнее правило
        /// «36 → 18, 44 → 17» расходилось с макетом на большинстве кнопок.
        ///
        /// Для символов, которых в макете нет (глобус веб-поиска появился после
        /// дизайна), остаётся прежнее приближение по размеру кнопки.
        static func glyph(for symbol: String, buttonSize: CGFloat) -> Font {
            if let size = designGlyph[symbol] {
                return Font.system(size: size)
            }
            return buttonSize <= AppMetrics.compactButton ? large : regular
        }

        /// Кегли из макета, снятые с узлов `icon/24/*`.
        private static let designGlyph: [String: CGFloat] = [
            "text.alignleft": 16,
            "ellipsis": 18,
            "chevron.left": 18,
            "xmark": 18,
            "checkmark": 18,
            "gearshape": 18,
            "plus": 18,
            "slider.horizontal.3": 18,
            "mic": 16,
            "arrow.up": 16,
            "stop.fill": 16,
        ]
    }
}

/// Применяет стиль из макета целиком: кегль, начертание, трекинг и межстрочный интервал.
///
/// Размер умножается на системный масштаб текста, поэтому вся типографика уважает
/// «Размер текста» в настройках. Раньше `Font.system(size:)` давал фиксированный кегль,
/// и приложение выглядело одинаково при любом системном размере.
private struct AppTextStyleModifier: ViewModifier {
    let style: AppTextStyle

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .font(.system(size: style.size * scale, weight: style.weight, design: style.design))
            .tracking(style.tracking * scale)
            .lineSpacing(max(0, (style.lineHeight - style.size) * scale))
    }
}

extension View {
    func appTextStyle(_ style: AppTextStyle) -> some View {
        modifier(AppTextStyleModifier(style: style))
    }
}
