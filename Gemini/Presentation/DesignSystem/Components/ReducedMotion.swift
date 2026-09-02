import SwiftUI

/// Анимация, которая уважает системное «Уменьшение движения».
///
/// Раньше это учитывал только индикатор ожидания, а переходы меню, баннера
/// и маршрута двигались всегда — именно они и мешают тем, кому движение неприятно.
private struct MotionAwareAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// То же, что `.animation(_:value:)`, но выключается при «Уменьшении движения».
    func motionAwareAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionAwareAnimation(animation: animation, value: value))
    }
}
