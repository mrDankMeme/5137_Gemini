import Foundation

/// Снимок данных аккаунта для экранов.
struct Account: Equatable, Sendable {
    let id: String
    /// Баланс токенов. `Decimal`, а не `Int`: сервер отдаёт дробное значение,
    /// и округление до целого превращает остаток в «токенов нет».
    let tokenBalance: Decimal
    /// Подписка по мнению бэкенда — из того же `/v1/policy/effective`, что
    /// и баланс. Второй, постоянный источник правды рядом с платформенным
    /// `EntitlementStatus`, а не запасной путь только на Debug — тот же
    /// принцип, что в 232 (`max(adaptyEnd, russianEnd, backendEnd)`). Бэкенд
    /// подтверждает то, что платформа не увидела: в Debug это тестовая
    /// транзакция `Debug.storekit` с локальным корнем Xcode, в проде так же
    /// нужен для RU-платежей, которые Adapty не видит вовсе.
    let isSubscribedOnBackend: Bool
}
