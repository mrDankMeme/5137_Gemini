import Foundation
import StoreKit

/// Цены наших подписок прямо из App Store — на случай, когда нужного продукта
/// нет в плейсменте Adapty.
///
/// Нужен ровно для одного: зачёркнутой цены на спецпредложении. Скидочный
/// недельный лежит в своём плейсменте один, а сравнивать его надо с обычным
/// недельным. Взять «$9.99» из головы нельзя — в других витринах он стоит
/// иначе, и зачёркнутая цена оказалась бы враньём рядом с настоящей.
/// StoreKit отдаёт цену для витрины конкретного пользователя.
enum StoreKitPriceProvider {
    struct Price: Sendable {
        let productID: String
        let displayPrice: String
        let amount: Decimal
        /// Длина периода подписки. `nil` — продукт не подписка.
        let periodUnit: Product.SubscriptionPeriod.Unit?
        let periodValue: Int?
    }

    /// Пустой массив — App Store не ответил. Это не ошибка сценария:
    /// вызывающая сторона просто не покажет то, что без цены не имеет смысла.
    static func prices(for productIDs: [String]) async -> [Price] {
        guard let products = try? await Product.products(for: productIDs) else {
            return []
        }
        return products.map { product in
            Price(
                productID: product.id,
                displayPrice: product.displayPrice,
                amount: product.price,
                periodUnit: product.subscription?.subscriptionPeriod.unit,
                periodValue: product.subscription?.subscriptionPeriod.value
            )
        }
    }
}
