import SwiftUI

/// Градиентная подложка под нижним блоком онбординга и пейволов.
///
/// В макете это отдельный кадр с линейным градиентом от прозрачного чёрного
/// к сплошному: он гасит арт под текстом, чтобы тот читался. Точка, в которой
/// градиент становится непрозрачным, у экранов разная — онбординг 0.5,
/// пейволы 0.3, — поэтому она задаётся снаружи.
struct BottomScrim: ViewModifier {
    /// Доля высоты блока, на которой градиент доходит до сплошного чёрного.
    let solidAt: Double

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: AppColor.bgPrimary.opacity(0), location: 0),
                        .init(color: AppColor.bgPrimary, location: solidAt),
                        .init(color: AppColor.bgPrimary, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
    }
}

extension View {
    /// Гасит фоновый арт под нижним блоком, как в макете.
    func bottomScrim(solidAt: Double) -> some View {
        modifier(BottomScrim(solidAt: solidAt))
    }
}
