import Foundation

/// Тариф или пакет токенов в том виде, в котором его показывает пейвол.
///
/// Платформа запрещает фильтровать и переупорядочивать продукты, поэтому список
/// доходит до вью как есть — включая случаи 0, 1 и повторяющихся SKU.
struct PaywallPlan: Identifiable, Equatable {
    let id: String
    /// «Annually», «Weekly».
    let title: String
    /// Вторая строка карточки: «$60 / year». У недельного тарифа её нет.
    let subtitle: String?
    /// Правая колонка: «$1.15 / week».
    let price: String
    /// Плашка «Save 60%» над карточкой. Показывается, только если задана.
    let badge: String?
    /// Искра перед названием — так в макете выглядят пакеты токенов.
    var showsSparkle = false
}
