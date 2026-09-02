import BroadMonetization
import Foundation

/// Собирает карточку тарифа из продукта платформы.
///
/// Вынесено из `PaywallCatalog`, потому что это не загрузка каталога, а правила
/// показа: как назвать период, что писать в правой колонке и когда рисовать
/// плашку выгоды.
///
/// Ничего не фильтрует и не переупорядочивает — платформа это запрещает.
/// Продукт без цены, без периода и с пустым названием обязан дорисоваться:
/// на пейволе видны все позиции, включая битые.
/// Обычный тариф, с которым сравнивается скидочный. Своё представление, а не
/// `MonetizationProduct`: цена может прийти и из Adapty, и напрямую из
/// App Store — сравнение от источника не зависит.
struct OfferBaseline: Equatable {
    enum Unit: Equatable {
        case day, week, month, year
    }

    let id: String
    let displayPrice: String
    let amount: Decimal
    let unit: Unit
    let count: Int
}

/// Спецпредложение, готовое к показу: все строки уже посчитаны из продуктов.
struct SpecialOffer: Equatable {
    let discountTitle: String
    let planName: String
    let planPeriod: String
    let price: String
    let crossedPrice: String
}

enum PaywallPlanFactory {
    /// Плашка «Save N%» считается по всему набору сразу: скидка существует
    /// только относительно самого дорогого тарифа в пересчёте на неделю,
    /// а Adapty отдельным полем её не отдаёт.
    /// `creditsPerGeneration` — цена самой дешёвой генерации из каталога
    /// `/v1/media/models`. Не знаем её — строку «сколько это генераций»
    /// не показываем вовсе: число с потолка на экране покупки хуже, чем
    /// его отсутствие.
    static func plans(
        for products: [MonetizationProduct],
        showsSparkle: Bool = false,
        creditsPerGeneration: Int? = nil
    ) -> [PaywallPlan] {
        // «За единицу» у подписки и у пакета токенов разное: там неделя, тут
        // один токен. Плашка выгоды в обоих случаях считается одинаково —
        // насколько единица дешевле, чем в самом невыгодном варианте.
        let unit = products.map(unitAmount(of:))
        let baseline = unit.compactMap { $0 }.max()
        // Плашка одна на весь экран — на самом выгодном варианте, как в макете:
        // там из четырёх пакетов подписан только верхний. Вешать её на каждый,
        // кто дешевле худшего, — уже не подсказка, а шум.
        let best = unit.compactMap { $0 }.min()

        return zip(products, unit).map { product, unitAmount in
            plan(
                for: product,
                unitAmount: unitAmount,
                baseline: baseline,
                isBestValue: unitAmount != nil && unitAmount == best,
                showsSparkle: showsSparkle,
                creditsPerGeneration: creditsPerGeneration
            )
        }
    }

    // MARK: Спецпредложение

    /// Готовое к показу спецпредложение или `nil`.
    ///
    /// `nil`, если продукта нет, если не с чем сравнивать или если «скидка»
    /// не выходит: рисовать зачёркнутую цену, взятую с потолка, нельзя —
    /// это ровно то, за что снимают с ревью.
    ///
    /// Сравниваем только с тарифом **того же периода**: «$4.99 в неделю против
    /// $59.99 в год» — не скидка, а подмена.
    static func specialOffer(
        for product: MonetizationProduct,
        comparedTo candidates: [OfferBaseline],
        remote: SpecialOfferRemoteConfiguration? = nil
    ) -> SpecialOffer? {
        guard let price = product.price?.amount,
              let displayPrice = product.displayPrice,
              let periodTitle = periodLength(product.subscriptionPeriod),
              let unit = baselineUnit(product.subscriptionPeriod.unit),
              let count = product.subscriptionPeriod.count
        else {
            return nil
        }

        // Зачёркнутая цена: сначала то, что задал продакт в remote config
        // пейвола, потом обычный тариф того же периода. Множитель предпочтительнее
        // фиксированного текста — «старая цена = новая x2» остаётся верным
        // в любой валюте, а «$9.99» врёт всем, у кого витрина не долларовая.
        let remoteAmount: Decimal? = remote?.crossedValue
            ?? remote?.priceMultiplier.map { price * $0 }
        let remoteDisplay: String? = remote?.crossedPrice
            ?? remoteAmount.flatMap { money($0, like: product) }

        let baselineAmount: Decimal
        let baselineDisplay: String
        if let remoteDisplay, let remoteAmount, remoteAmount > price {
            baselineAmount = remoteAmount
            baselineDisplay = remoteDisplay
        } else if let crossedPrice = remote?.crossedPrice, remoteAmount == nil {
            // Задали только текст: показать можем, посчитать процент — нет.
            return SpecialOffer(
                discountTitle: remote?.badge ?? "",
                planName: product.title ?? String(localized: "Special for you"),
                planPeriod: remote?.periodText ?? periodTitle,
                price: displayPrice,
                crossedPrice: crossedPrice
            )
        } else {
            let baseline = candidates.first { candidate in
                candidate.id != product.productID.rawValue
                    && candidate.unit == unit
                    && candidate.count == count
                    && candidate.amount > price
            }
            if let baseline {
                baselineAmount = baseline.amount
                baselineDisplay = baseline.displayPrice
            } else if let fallback = money(
                price * AppConfiguration.specialOfferCrossedPriceMultiplier,
                like: product
            ) {
                // Тарифа того же периода в пейволе не оказалось — считаем
                // «старую» цену сами, по домашнему множителю. Это не выдумка
                // из воздуха: сумма получается из настоящей цены продукта и
                // в валюте витрины пользователя.
                //
                // Иначе кампания молча не показывалась: продакт включает
                // тумблер, а экрана нет, потому что основной пейвол в этот
                // день отдавал только месяц и год.
                baselineAmount = price * AppConfiguration.specialOfferCrossedPriceMultiplier
                baselineDisplay = fallback
            } else {
                // Даже отформатировать не удалось — показываем предложение
                // без зачёркнутой цены, как это делают 232 и 6010.
                return SpecialOffer(
                    discountTitle: remote?.badge ?? "",
                    planName: product.title ?? String(localized: "Special for you"),
                    planPeriod: remote?.periodText ?? periodTitle,
                    price: displayPrice,
                    crossedPrice: ""
                )
            }
        }

        var raw = (baselineAmount - price) / baselineAmount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, .down)
        let percent = (rounded as NSDecimalNumber).intValue
        guard percent >= 1 else {
            return nil
        }

        return SpecialOffer(
            discountTitle: remote?.badge ?? String(localized: "\(percent)% OFF"),
            planName: product.title ?? String(localized: "Special for you"),
            planPeriod: remote?.periodText ?? periodTitle,
            price: displayPrice,
            crossedPrice: baselineDisplay
        )
    }

    /// Тариф Adapty как кандидат на зачёркнутую цену.
    static func baseline(from product: MonetizationProduct) -> OfferBaseline? {
        guard let amount = product.price?.amount,
              let displayPrice = product.displayPrice,
              let unit = baselineUnit(product.subscriptionPeriod.unit),
              let count = product.subscriptionPeriod.count
        else {
            return nil
        }
        return OfferBaseline(
            id: product.productID.rawValue,
            displayPrice: displayPrice,
            amount: amount,
            unit: unit,
            count: count
        )
    }

    private static func baselineUnit(_ unit: SubscriptionPeriod.Unit) -> OfferBaseline.Unit? {
        switch unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        case .custom, .unknown: nil
        }
    }

    /// Длина периода словами — «1 week». Не то же, что `periodTitle`:
    /// там название тарифа («Weekly»), здесь срок.
    private static func periodLength(_ period: SubscriptionPeriod) -> String? {
        guard let count = period.count, count > 0 else {
            return nil
        }
        if count == 1 {
            switch period.unit {
            case .day: return String(localized: "1 day")
            case .week: return String(localized: "1 week")
            case .month: return String(localized: "1 month")
            case .year: return String(localized: "1 year")
            case .custom, .unknown: return nil
            }
        }

        switch period.unit {
        case .day: return String(localized: "\(count) days")
        case .week: return String(localized: "\(count) weeks")
        case .month: return String(localized: "\(count) months")
        case .year: return String(localized: "\(count) years")
        case .custom, .unknown: return nil
        }
    }

    private nonisolated static func unitAmount(of product: MonetizationProduct) -> Decimal? {
        if let tokens = tokenAmount(of: product), tokens > 0, let price = product.price?.amount {
            return price / Decimal(tokens)
        }
        return weeklyAmount(of: product)
    }

    /// Сколько токенов в пакете. Adapty присылает у всех пакетов одинаковый
    /// `title` «Tokens», поэтому на экране стояли пять неразличимых строк —
    /// количество есть только в идентификаторе продукта (`100_tokens_9.99`).
    /// Разбираем узко: ведущее число перед `_token`, иначе `nil`.
    private nonisolated static func tokenAmount(of product: MonetizationProduct) -> Int? {
        let sku = product.productID.rawValue
        guard let match = sku.range(of: #"^\d+(?=_tokens?)"#, options: .regularExpression) else {
            return nil
        }
        return Int(sku[match])
    }

    private static func plan(
        for product: MonetizationProduct,
        unitAmount: Decimal?,
        baseline: Decimal?,
        isBestValue: Bool,
        showsSparkle: Bool,
        creditsPerGeneration: Int?
    ) -> PaywallPlan {
        // Пакет токенов: в макете заголовок — само количество, под ним сколько
        // это генераций, справа цена как есть. Пересчёт на неделю тут не при чём.
        if let tokens = tokenAmount(of: product) {
            return PaywallPlan(
                id: product.id.rawValue,
                title: "\(tokens)",
                // «До», а не ровно столько: цена генерации зависит от модели и
                // ступени качества — от 4 кредитов за картинку до 32 за видео.
                // Считаем по самой дешёвой, поэтому это верхняя граница.
                subtitle: creditsPerGeneration.map { price in
                    String(localized: "up to \(tokens / max(price, 1)) generations")
                },
                price: product.displayPrice ?? "",
                badge: isBestValue ? badge(unitAmount: unitAmount, baseline: baseline) : nil,
                showsSparkle: showsSparkle
            )
        }

        // Правая колонка — всегда цена за неделю: сравнивать «$19.99» с «$59.99»
        // пользователь не должен, в этом весь смысл пересчёта. Если периода нет
        // (пакеты токенов, битый продукт), остаётся цена как есть.
        let price: String
        if let weeklyAmount = weeklyAmount(of: product), let weekly = money(weeklyAmount, like: product) {
            price = String(
                localized: "\(weekly) / week",
                comment: "Правая колонка карточки тарифа: цена в пересчёте на неделю"
            )
        } else {
            price = product.displayPrice ?? ""
        }

        return PaywallPlan(
            id: product.id.rawValue,
            title: title(for: product),
            subtitle: subtitle(for: product),
            price: price,
            badge: isBestValue ? badge(unitAmount: unitAmount, baseline: baseline) : nil,
            showsSparkle: showsSparkle
        )
    }

    // MARK: Название

    /// Период вперёд названия из Adapty: у продуктов проекта `title` пустой,
    /// и на карточку уходил сырой SKU вида `monthly_19.99_nottrial`.
    /// Название из Adapty остаётся запасным — им подписаны пакеты токенов,
    /// у которых периода нет.
    private static func title(for product: MonetizationProduct) -> String {
        periodTitle(product.subscriptionPeriod)
            ?? product.title
            ?? product.productID.rawValue
    }

    private static func periodTitle(_ period: SubscriptionPeriod) -> String? {
        guard let count = period.count, count > 0 else {
            return nil
        }

        if count == 1 {
            switch period.unit {
            case .day: return String(localized: "Daily")
            case .week: return String(localized: "Weekly")
            case .month: return String(localized: "Monthly")
            case .year: return String(localized: "Annually")
            case .custom, .unknown: return nil
            }
        }

        switch period.unit {
        case .day: return String(localized: "Every \(count) days")
        case .week: return String(localized: "Every \(count) weeks")
        case .month: return String(localized: "Every \(count) months")
        case .year: return String(localized: "Every \(count) years")
        case .custom, .unknown: return nil
        }
    }

    // MARK: Вторая строка

    /// Сколько списывают на самом деле — «$59.99 / year» под названием.
    /// У недельного тарифа не показывается: там это дословно повторило бы
    /// правую колонку.
    private static func subtitle(for product: MonetizationProduct) -> String? {
        let period = product.subscriptionPeriod
        guard let displayPrice = product.displayPrice,
              let count = period.count, count > 0,
              !(period.unit == .week && count == 1)
        else {
            // У пакетов токенов периода нет — там подпись приходит из Adapty.
            return product.subtitle
        }

        if count == 1 {
            switch period.unit {
            case .day: return String(localized: "\(displayPrice) / day")
            case .week: return String(localized: "\(displayPrice) / week")
            case .month: return String(localized: "\(displayPrice) / month")
            case .year: return String(localized: "\(displayPrice) / year")
            case .custom, .unknown: return product.subtitle
            }
        }

        switch period.unit {
        case .day: return String(localized: "\(displayPrice) / \(count) days")
        case .week: return String(localized: "\(displayPrice) / \(count) weeks")
        case .month: return String(localized: "\(displayPrice) / \(count) months")
        case .year: return String(localized: "\(displayPrice) / \(count) years")
        case .custom, .unknown: return product.subtitle
        }
    }

    // MARK: Выгода

    private static func badge(unitAmount: Decimal?, baseline: Decimal?) -> String? {
        guard let unitAmount, let baseline, baseline > 0, unitAmount < baseline else {
            return nil
        }

        // Округление вниз и обязательно через `NSDecimalRound`: обещать
        // «Save 75%» там, где выходит 74.9%, нельзя, а `intValue` у
        // `NSDecimalNumber` с длинной мантиссой (74.99166249791562447890…)
        // возвращает 0 — плашка не появлялась бы никогда.
        var raw = (baseline - unitAmount) / baseline * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 0, .down)
        let percent = (rounded as NSDecimalNumber).intValue
        guard percent >= 1 else {
            return nil
        }

        return String(localized: "Save \(percent)%")
    }

    // MARK: Счёт

    /// Цена за неделю. `nil`, если период неизвестен или цены нет —
    /// выдумывать число в таком случае хуже, чем не показать пересчёт.
    private nonisolated static func weeklyAmount(of product: MonetizationProduct) -> Decimal? {
        guard let amount = product.price?.amount,
              let weeks = weeks(in: product.subscriptionPeriod),
              weeks > 0
        else {
            return nil
        }
        return amount / weeks
    }

    /// Сколько недель в периоде. Месяц и год считаются через год из 52 недель,
    /// а не «месяц = 4 недели»: при четырёх неделях в год попадает 48, и годовой
    /// тариф выглядел бы на 8% выгоднее, чем он есть.
    private nonisolated static func weeks(in period: SubscriptionPeriod) -> Decimal? {
        guard let count = period.count, count > 0 else {
            return nil
        }
        let multiplier: Decimal
        switch period.unit {
        case .day: multiplier = Decimal(1) / 7
        case .week: multiplier = 1
        case .month: multiplier = Decimal(52) / 12
        case .year: multiplier = 52
        case .custom, .unknown: return nil
        }
        return Decimal(count) * multiplier
    }

    // MARK: Формат цены

    /// Пересчитанная цена в оформлении магазина.
    ///
    /// Форматировать по локали устройства нельзя: на русском устройстве с
    /// американской витриной в одной карточке оказывались «$19.99 / month»
    /// от StoreKit и «US$4,61 / week» от нас — разный символ и разный
    /// разделитель в двух строках подряд. Поэтому берём оформление прямо из
    /// `displayPrice`: что стоит до числа и после, каким знаком отделена
    /// дробная часть и есть ли она вообще (у иены нет).
    private static func money(_ amount: Decimal, like product: MonetizationProduct) -> String? {
        guard let displayPrice = product.displayPrice else {
            return fallbackMoney(amount, currency: product.price?.currencyCode)
        }
        guard let range = displayPrice.range(
            of: #"[0-9][0-9.,\u{00A0}\u{202F} ]*[0-9]|[0-9]"#,
            options: .regularExpression
        ) else {
            return fallbackMoney(amount, currency: product.price?.currencyCode)
        }

        let prefix = String(displayPrice[displayPrice.startIndex ..< range.lowerBound])
        let suffix = String(displayPrice[range.upperBound...])
        let numeric = displayPrice[range].trimmingCharacters(in: .whitespaces)

        // Разделитель дробной части — последний «.» или «,», за которым стоят
        // ровно одна-две цифры. Иначе это разделитель разрядов: в «¥1,200»
        // запятая отделяет тысячи, а копеек у валюты нет.
        var separator: String?
        if let last = numeric.lastIndex(where: { $0 == "." || $0 == "," }) {
            let tail = numeric[numeric.index(after: last)...]
            if (1 ... 2).contains(tail.count), tail.allSatisfy(\.isNumber) {
                separator = String(numeric[last])
            }
        }

        var rounded = Decimal()
        var raw = amount
        NSDecimalRound(&rounded, &raw, separator == nil ? 0 : 2, .plain)

        var text = "\(rounded)"
        if let separator {
            var parts = text.components(separatedBy: ".")
            if parts.count == 1 {
                parts.append("")
            }
            while parts[1].count < 2 {
                parts[1] += "0"
            }
            text = parts[0] + separator + parts[1].prefix(2)
        }
        return prefix + text + suffix
    }

    private static func fallbackMoney(_ amount: Decimal, currency: String?) -> String? {
        guard let currency else {
            return nil
        }
        return amount.formatted(.currency(code: currency))
    }
}
