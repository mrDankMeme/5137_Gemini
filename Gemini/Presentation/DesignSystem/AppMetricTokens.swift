import CoreGraphics

/// Размеры из макета. Единственное место, где живут числа вёрстки: правило
/// платформы требует брать размеры во вью из токенов, а не из литералов.
///
/// Макет нарисован на кадре 402×874 — это iPhone 16 Pro. Ширина нигде не
/// фиксируется: контент тянется по экрану и отступает от краёв на `screenPadding`.
enum AppMetrics {
    // MARK: Отступы и общие размеры

    /// Боковые поля контента: 402 − 370 = 32, то есть по 16 с каждой стороны.
    static let screenPadding: CGFloat = 16
    /// Отступ шапки от статус-бара: навбар в макете 138 = 62 + 16 + 44 + 16.
    static let headerInset: CGFloat = 16
    /// Центр нижнего свечения главного экрана — от верха экрана, как в макете.
    static let homeGlowCenterY: CGFloat = 824

    /// Минимальная зона нажатия по рекомендации Apple.
    static let tapTarget: CGFloat = 44
    /// Шаг между блоками ответа ассистента.
    static let answerBlockGap: CGFloat = 24
    /// Шаг между заголовком раздела и его содержимым внутри ответа.
    ///
    /// В макете лента ответа двухуровневая: разделы отделены 24, а заголовок
    /// от своего текста — 12. Ровный шаг делал ответ плотнее макета.
    static let answerHeadingGap: CGFloat = 12

    /// Карточка алерта из макета: 370×390, радиус 34, шаг между блоками 10.
    static let alertWidth: CGFloat = 370
    static let alertRadius: CGFloat = 34
    static let alertSpacing: CGFloat = 10

    /// Иконка-превью пропорций в шторке параметров генерации.
    ///
    /// В макете у всех неквадратных одинаковая площадь: 14×18, 18×14, 21×12
    /// и 12×21 — это ровно 252. Так широкая и высокая рамки читаются одинаково
    /// весомо. Квадрат нарисован крупнее — 18×18.
    static let ratioIconArea: CGFloat = 252
    static let ratioIconSquare: CGFloat = 18

    /// Знак в попапе оценки: искра без подложки. Было 120 — заметно
    /// перевешивала карточку 370 pt шириной, уменьшена по просьбе.
    static let popupMark: CGFloat = 96

    /// Компенсация центровки приветствия на главном экране.
    ///
    /// В макете блок «Ready when you are» отцентрован по **всему экрану**
    /// (constraints CENTER/CENTER, центр 437 = 874/2), а стек центрует его по
    /// промежутку между шапкой (138) и нижней полосой (106) — это на 16 pt ниже.
    /// Лишнее место под блоком поднимает его на половину, поэтому 32.
    static let homeGreetingCenteringInset: CGFloat = 32

    /// Зазор под полем ввода: до зоны домашнего индикатора, а с поднятой
    /// клавиатурой — до неё. В макете 8 (поле кончается на 832, индикатор с 840).
    static let composerBottomGap: CGFloat = 8

    /// Отступ от края поля ввода до кружков внутри.
    ///
    /// В макете он 8, но считается до **видимого** кружка 36 pt, а в раскладке
    /// кнопка занимает 44 — зону нажатия по норме Apple. Невидимые 4 pt с каждой
    /// стороны уже дают половину отступа, поэтому здесь 4: иначе поле выходит
    /// 60 pt вместо 52 из макета.
    static let composerPadding: CGFloat = 4

    /// Воздух по бокам текста в поле ввода. Кружки по краям несут невидимый
    /// паддинг до зоны нажатия 44 pt, поэтому от кнопок текст отделён, а вот
    /// каретка вставала вплотную к последней букве и наезжала на неё.
    static let composerTextInset: CGFloat = 6
    /// Высота строки ввода из макета (`Text Input` 16/22.4): без неё строка
    /// выходит на 2 pt ниже и развёрнутое поле не добирает до 102 pt.
    static let composerLineHeight: CGFloat = 22
    /// Зазор между строкой текста и рядом кнопок в развёрнутом поле.
    /// В макете между ними 20 видимых точек, из которых 4 даёт невидимый
    /// припуск зоны нажатия у кнопок.
    static let composerRowSpacing: CGFloat = 16

    // MARK: Кнопки

    /// Высота главной кнопки.
    static let buttonHeight: CGFloat = 54
    /// Высота широкой кнопки в шторках: «Apply», «Cancel subscription».
    static let sheetButtonHeight: CGFloat = 56
    /// Скругление главной кнопки — половина высоты, то есть капсула.
    static let buttonRadius: CGFloat = 32
    /// Круглая кнопка в навбаре.
    static let navButton: CGFloat = 44
    /// Круглая кнопка в поле ввода.
    static let compactButton: CGFloat = 36
    /// Круглая кнопка действия под генерацией.
    static let actionButton: CGFloat = 56
    /// Ширина второстепенной кнопки рядом с главной — «Not Now» на экране
    /// согласия ИИ.
    static let secondaryButtonWidth: CGFloat = 120

    // MARK: Скругления

    /// Карточки: тарифы, пакеты токенов.
    static let cardRadius: CGFloat = 20
    /// Чипы и бейджи.
    static let badgeRadius: CGFloat = 16
    /// На сколько плашка выгоды выступает над верхней границей своей карточки.
    /// В макете плашка 21 pt сидит на границе, выходя за неё наполовину
    /// (`Badge Container` @ y=519 при карточке с 529).
    static let badgeRise: CGFloat = 10.5
    /// Строка настроек.
    static let rowRadius: CGFloat = 40
    /// Пузырь сообщения и поле ввода.
    static let bubbleRadius: CGFloat = 32
    /// Шторка снизу.
    static let sheetRadius: CGFloat = 47

    // MARK: Иконки и знаки

    /// Иконка в строке и в кнопке.
    static let icon: CGFloat = 24
    /// Радиокнопка выбора тарифа.
    static let controlSize: CGFloat = 24
    /// Иконка на карточке вложения.
    static let attachmentIcon: CGFloat = 32
    /// Искра в списке возможностей пейвола.
    static let sparkleSmall: CGFloat = 16
    /// Искра в кнопке Pro и в карточке пакета токенов.
    static let sparkleMedium: CGFloat = 20
    /// Знак приложения на splash и в попапе обновления.
    static let appMarkLarge: CGFloat = 140
    /// Знак приложения в ин-апп баннере.
    static let appMarkSmall: CGFloat = 38
    /// Доля искры внутри знака приложения — 83 из 140.
    static let appMarkSparkleRatio: CGFloat = 83.0 / 140.0
    /// Скругление знака приложения — 32 из 140.
    static let appMarkRadiusRatio: CGFloat = 32.0 / 140.0

    // MARK: Строки списков

    /// Строка настроек.
    static let settingsRow: CGFloat = 44
    /// Строка меню и списка чатов.
    static let menuRow: CGFloat = 40
    /// Карточка тарифа.
    static let planRow: CGFloat = 72
    /// Вариант выбора в параметрах генерации.
    static let optionRow: CGFloat = 48

    // MARK: Экраны и элементы

    /// Максимальная ширина пузыря пользователя.
    static let bubbleMaxWidth: CGFloat = 322
    /// Ширина меню выбора модели.
    /// Размытие верхнего свечения. В макете у слоя стоит layer blur 300;
    /// у Figma радиус вдвое крупнее гауссова, которым размывает SwiftUI.
    static let artworkGlowBlur: CGFloat = 130
    /// Карточка источника под ответом. Фиксированная: у разной ширины
    /// карточек лента источников выглядит рваной.
    static let sourceChipWidth: CGFloat = 180
    static let modelMenuWidth: CGFloat = 260
    /// Потолок высоты списка моделей: каталог приходит с backend, и сколько
    /// в нём строк — заранее неизвестно.
    static let modelMenuMaxHeight: CGFloat = 420
    /// Шаг иконок под ответом: 24 pt значок и 12 pt промежуток из макета.
    /// Он же ширина зоны нажатия — накладывать зоны друг на друга нельзя,
    /// верхняя перехватывает нажатия соседней.
    static let assistantActionStep: CGFloat = 36
    /// Отступ меню моделей от верха: под чипом в шапке.
    static let modelMenuTopInset: CGFloat = 55
    /// Карточка вложения над полем ввода.
    static let attachmentCard: CGFloat = 100
    /// Ширина текста на карточке вложения.
    static let attachmentLabelWidth: CGFloat = 76
    /// Плитка выбора источника вложения.
    static let attachmentSourceTile: CGFloat = 80
    /// Ширина карточки обратного отсчёта.
    /// Верх блока «Special Offer / 50% OFF» — от верха экрана, как в макете.
    /// Не по центру свободного места: у нижней части высота своя, и центрирование
    /// уводило заголовок с таймером на 26 pt вверх.
    static let specialOfferHeadlineTop: CGFloat = 194
    static let countdownWidth: CGFloat = 282
    /// Ширина колонки с разрядом отсчёта.
    static let countdownUnitWidth: CGFloat = 64
    /// Кнопка проигрывания: и на плитке библиотеки, и в просмотре генерации —
    /// в макете она там и там 56 pt.
    static let playButton: CGFloat = 56
    /// Ширина кнопки повтора на splash.
    static let retryMaxWidth: CGFloat = 220
    /// Дорожка звука во время диктовки.
    static let waveformHeight: CGFloat = 28.5
    static let waveformBarWidth: CGFloat = 2
    static let waveformBarGap: CGFloat = 2
    /// Полоса-разделитель в ответе ассистента.
    static let hairline: CGFloat = 1
    /// Точка внутри выбранной радиокнопки.
    static let radioDot: CGFloat = 8
    /// Градиент под кнопкой настроек в меню.
    static let menuScrimHeight: CGFloat = 110

    // MARK: Свечение

    /// Ширина эллипса свечения из макета.
    static let glowWidth: CGFloat = 622
    /// Высота свечения на главном экране и онбординге.
    static let glowHeightTall: CGFloat = 560
    /// Высота свечения на пейволе подписки.
    static let glowHeightPaywall: CGFloat = 453
    /// Высота свечения на пейволе токенов.
    static let glowHeightTokens: CGFloat = 404

    // MARK: Высоты шторок

    static let attachmentSheetHeight: CGFloat = 192
    static let currentPlanSheetHeight: CGFloat = 262
    /// 40 сверху + искра 120 + 24 + текст 76 + 24 + кнопки 116 + 16 снизу.
    static let ratePopupHeight: CGFloat = 416
    /// 40 сверху + знак 140 + 24 + текст 69 + 24 + кнопки 108 + 16 снизу.
    static let appUpdateSheetHeight: CGFloat = 421

    // MARK: Пропорции

    /// Карточка генерации в переписке — 330×442.
    static let generationCardRatio: CGFloat = 442.0 / 330.0
    /// Картинка в просмотре генерации — 370×554.
    static let generationPreviewRatio: CGFloat = 370.0 / 554.0
}
