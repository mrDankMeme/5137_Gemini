import BroadCore
import Foundation

/// Запуск приложения через движок платформы.
///
/// Шаги выполняются до первого экрана: критические — обязательно, фоновые —
/// после. Пока подключать нечего, список пуст, но машинерия на месте: активация
/// Adapty и прогрев каталога добавятся сюда, а не в `onAppear` какого-нибудь вью.
///
/// `AppFlow` открывается только на `.ready` или `.degraded` — так требует
/// `Documentation/AppFlow.md`. На `.failed` splash показывает повтор.
@Observable
@MainActor
final class AppBootstrap {
    private(set) var state: AppBootstrapState = .idle

    private let useCase: any RunAppBootstrapUseCaseProtocol

    init(useCase: any RunAppBootstrapUseCaseProtocol) {
        self.useCase = useCase
    }

    /// Готово ли приложение показывать маршрут.
    ///
    /// `degraded` тоже годится: часть необязательных шагов не удалась,
    /// но пользоваться приложением можно.
    var isReady: Bool {
        state == .ready || state == .degraded
    }

    var failure: AppError? {
        if case let .failed(error) = state { return error }
        return nil
    }

    func start() async {
        state = await useCase()
    }

    func retry() async {
        state = await useCase.retry()
    }
}
