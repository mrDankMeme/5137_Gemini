import SwiftUI

/// Индикатор ожидания ответа: фирменная искра, которая вращается и пульсирует.
///
/// В макете это кадр `Loader` 32×32 из четырёх обводочных лучей. Собран формой,
/// а не GIF-ом: чётко на любом экране и уважает «Уменьшение движения».
struct SparkleLoader: View {
    var size: CGFloat = 32

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SparkleShape(concavity: 0.75)
            .stroke(AppColor.textPrimary, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .opacity(isAnimating ? 1 : 0.45)
            .animation(
                reduceMotion
                    ? nil
                    : .linear(duration: 1.4).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
            .accessibilityElement()
            .accessibilityLabel("Generating a reply")
    }
}
