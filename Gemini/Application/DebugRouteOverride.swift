#if DEBUG
    import BroadUIFlows
    import Foundation

    /// Debug-инструмент: открыть нужный экран сразу, минуя маршрут запуска.
    ///
    /// Нужен, чтобы проверять пейвол или главный экран, не проходя онбординг заново,
    /// и чтобы тестировщик мог снять конкретный экран одной командой:
    ///
    /// ```
    /// xcrun simctl launch <device> com.ras.5137g4m769 -route paywall
    /// ```
    ///
    /// В Release этого кода нет.
    enum DebugRouteOverride {
        /// Считается один раз: аргументы запуска не меняются, а `var` пересчитывался
        /// бы на каждую перерисовку корневого экрана.
        static let route: AppFlowRoute? = {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-route"),
                  index + 1 < arguments.count
            else {
                return nil
            }

            switch arguments[index + 1] {
            case "launch": return .launch
            case "onboarding": return .onboarding
            case "paywall": return .initialPaywall
            case "main": return .main
            default: return nil
            }
        }()
    }
#endif
