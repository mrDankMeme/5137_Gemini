#if DEBUG
    import Foundation

    /// ⚠️ ТОЛЬКО DEBUG: ручное зачисление тестеру после локальной sandbox-покупки.
    ///
    /// Локальная StoreKit-транзакция в Debug не подписана так, как настоящая
    /// от App Store Server Notifications, — бэк не может проверить её сам.
    /// Вызывается сразу после успешной покупки тем же ID, что уже виден
    /// в Settings как «Account ID» и что ушёл в Adapty как `customerUserID`.
    ///
    /// `ADMIN_KEY` — переменная окружения Run-схемы (`project.yml`), не литерал
    /// в коде: без неё, как и без сети, вызов тихо ничего не делает — упасть
    /// из-за дебажной надстройки настоящая покупка не должна.
    enum DebugAdminGrant {
        enum Kind {
            case subscription
            case wallet

            var path: String {
                switch self {
                case .subscription: "/v1/admin/subscription/grant"
                case .wallet: "/v1/admin/wallet/grant"
                }
            }

            /// Тело запроса под конкретную ручку. `nil` — SKU не по одному
            /// из наших шаблонов, начислять нечего.
            func body(accountID: String, productID: String) -> [String: Any]? {
                switch self {
                case .subscription:
                    guard let days = Self.subscriptionDays(for: productID) else { return nil }
                    return [
                        "userId": accountID,
                        "days": days,
                        "plan": "manual_grant",
                        "idempotencyKey": "debug-sub-\(UUID().uuidString)"
                    ]
                case .wallet:
                    guard let amount = Self.tokenAmount(for: productID) else { return nil }
                    return [
                        "userId": accountID,
                        "amount": amount,
                        "idempotencyKey": "debug-tokens-\(UUID().uuidString)",
                        "reason": "debug paywall grant"
                    ]
                }
            }

            /// Ведущее число перед `_token`/`_tokens` — `100_tokens_9.99` → 100.
            /// Тот же разбор, что в `PaywallPlanFactory.tokenAmount(of:)`.
            private static func tokenAmount(for productID: String) -> Int? {
                guard let match = productID.range(of: #"^\d+(?=_tokens?)"#, options: .regularExpression)
                else {
                    return nil
                }
                return Int(productID[match])
            }

            /// Период называет себя в самом SKU (`weekly_…`, `monthly_…`,
            /// `yearly_…`, `offer_week_…`) — считать его отдельно незачем.
            private static func subscriptionDays(for productID: String) -> Int? {
                if productID.hasPrefix("yearly") { return 365 }
                if productID.hasPrefix("monthly") { return 30 }
                if productID.hasPrefix("weekly") || productID.hasPrefix("offer_week") { return 7 }
                return nil
            }
        }

        /// `nil` — начислено. Иначе короткая причина для тестера.
        ///
        /// Тело раньше было `{userId, productId}` для обеих ручек — ни одна
        /// его не принимает. `/v1/admin/wallet/grant` ждёт
        /// `{userId, amount, idempotencyKey, reason}`, `/v1/admin/subscription/grant`
        /// — `{userId, days, plan, idempotencyKey}`; это уже было записано
        /// в CLAUDE.md проекта, но сам код так и остался старым. Тот же
        /// контракт, что в `DebugAdminGrantService` у 232.
        ///
        /// Раньше результат ещё и выбрасывался (`_ = try? await …`), и это
        /// вдвойне скрывало проблему: неверное тело плюс невидимый ответ —
        /// покупка в Debug молча не зачислялась, выглядело как «бэк не отдал
        /// баланс».
        @discardableResult
        static func grant(kind: Kind, accountID: String, productID: String) async -> String? {
            guard
                let adminKey = ProcessInfo.processInfo.environment["ADMIN_KEY"],
                !adminKey.isEmpty
            else {
                return "ADMIN_KEY не задан в схеме"
            }
            guard let url = URL(string: kind.path, relativeTo: AppConfiguration.apiBaseURL) else {
                return "неверный адрес ручки начисления"
            }
            guard let body = kind.body(accountID: accountID, productID: productID) else {
                return "не удалось разобрать SKU «\(productID)» для отладочного начисления"
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(adminKey, forHTTPHeaderField: "X-Admin-Token")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse
            else {
                return "начисление не ушло: нет сети"
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                // Машинный код сервера, а не текст системной ошибки: по нему
                // сразу видно, ключ ли виноват.
                let code = (try? JSONDecoder().decode(AdminErrorDTO.self, from: data))?.error.code
                return "начисление отклонено: HTTP \(http.statusCode)" + (code.map { ", \($0)" } ?? "")
            }
            return nil
        }
    }

    private nonisolated struct AdminErrorDTO: Decodable {
        struct Payload: Decodable {
            let code: String
        }

        let error: Payload
    }
#endif
