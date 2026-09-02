import SwiftUI

/// Палитра из Figma: страница «🧱 design system» → секция Colors.
/// Названия повторяют Color Role дизайна, чтобы вёрстку можно было сверять глазами.
/// Приложение работает только в тёмной теме (`UIUserInterfaceStyle = Dark`),
/// поэтому у ролей один режим — как и в макете.
enum AppColor {
    // MARK: Accent

    /// Accent/primary — `#1F3B9B`. Кнопки, выбранный тариф, отправка сообщения.
    static let accent = Color(hex: 0x1F3B9B)
    /// Светлый акцент: обводка иконок в чипах подсказок и цена со скидкой
    /// на спецпредложении. В макете это один и тот же `#7495FF`.
    static let accentLight = Color(hex: 0x7495FF)

    // MARK: Background

    /// Bg/primary — `#000000`. Фон всех экранов.
    static let bgPrimary = Color(hex: 0x000000)
    /// Bg/secondary — `#1B1D26`. Карточки, поле ввода, пузырь пользователя.
    static let bgSecondary = Color(hex: 0x1B1D26)
    /// Bg/overlay — `#000000` 20%. Затемнение под шторками и модалками.
    static let bgOverlay = Color(hex: 0x000000, opacity: 0.2)
    /// Bg/grey — `#E1E3E6`. Светлые подложки (шеринг, превью).
    static let bgGrey = Color(hex: 0xE1E3E6)
    /// Карточка тарифа на спецпредложении — `#FFFFFF` 14%.
    static let bgElevatedStrong = Color(hex: 0xFFFFFF, opacity: 0.14)
    /// Подложка чипов-подсказок — `#FFFFFF` 10%.
    /// Совпадает по значению со `strokePrimary`, но роль другая: это фон, не обводка.
    static let bgElevated = Color(hex: 0xFFFFFF, opacity: 0.1)

    // MARK: Text

    /// Text/white — `#FFFFFF`. Основной текст.
    static let textPrimary = Color(hex: 0xFFFFFF)
    /// Text/white 70 — `#FFFFFF` 70%. Вторичный текст, подписи.
    static let textSecondary = Color(hex: 0xFFFFFF, opacity: 0.7)
    /// Text/white 50 — `#FFFFFF` 50%. Плейсхолдеры, неактивное.
    static let textTertiary = Color(hex: 0xFFFFFF, opacity: 0.5)
    /// Значение справа в строке настроек. В макете это системный цвет iOS
    /// `#EBEBF5` — почти белый с холодным оттенком, а не чистый белый.
    static let rowDetail = Color(hex: 0xEBEBF5, opacity: 0.6)
    /// Шеврон в строке настроек: тот же системный цвет, но заметно тусклее.
    static let rowChevron = Color(hex: 0xEBEBF5, opacity: 0.3)
    /// Подложка кнопки проигрывания поверх генерации: в макете `#1E1E1E` 50%,
    /// а не полупрозрачный чёрный — на светлом кадре разница видна.
    /// Затемнение поверх снимка, пока файл грузится — `#000000` 20% из макета.
    static let uploadScrim = Color(hex: 0x000000, opacity: 0.2)

    static let playBackdrop = Color(hex: 0x1E1E1E, opacity: 0.5)
    /// Тонировка стеклянной карточки алерта поверх размытия — в макете
    /// `#000000` 60%, поверх него еле заметная светлая подсветка `#FFFFFF` 6%.
    static let alertTint = Color(hex: 0x000000, opacity: 0.6)
    static let alertHighlight = Color(hex: 0xFFFFFF, opacity: 0.06)
    /// Text/black — `#121212`. Текст на светлых подложках.
    static let textOnLight = Color(hex: 0x121212)

    // MARK: Stroke

    /// Stroke/white 10 — `#FFFFFF` 10%. Обводка карточек и чипов.
    static let strokePrimary = Color(hex: 0xFFFFFF, opacity: 0.1)
    /// Stroke/white 5 — `#FFFFFF` 5%. Разделители внутри карточек.
    static let strokeSecondary = Color(hex: 0xFFFFFF, opacity: 0.05)
    /// Stroke/grey — `#EEEFF2`. Обводка на светлых подложках.
    static let strokeOnLight = Color(hex: 0xEEEFF2)
    /// Stroke/black 5 — `#000000` 5%. Разделители на светлых подложках.
    static let strokeOnLightSubtle = Color(hex: 0x000000, opacity: 0.05)

    // MARK: Состояния

    // Этих ролей нет на странице дизайн-системы — они встречаются только на экранах
    // чата, поэтому значения взяты прямо из кадров Figma и подписаны, где именно.

    /// Фон баннера о лимите (`Notification` в чате) — `#062243`.
    static let noticeBackground = Color(hex: 0x062243)
    /// Каретка в поле поиска — `#0088FF`.
    static let caret = Color(hex: 0x0088FF)
    /// Обводка и кнопка баннера о лимите — `#0085FF`.
    static let noticeAccent = Color(hex: 0x0085FF)
    /// Текст на кнопке баннера — `#FAFBF6`.
    static let onNoticeAccent = Color(hex: 0xFAFBF6)
    /// Ошибка генерации: обводка и текст пузыря — `#EF5A5D`.
    static let error = Color(hex: 0xEF5A5D)
    /// Приглушённый текст: подпись баннера, юридическая строка — `#B9BABA`.
    static let textMuted = Color(hex: 0xB9BABA)
    /// Необратимое действие: отмена подписки, удаление — `#FF5053`.
    static let destructive = Color(hex: 0xFF5053)
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
