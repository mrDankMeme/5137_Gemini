import SwiftUI

/// Четырёхлучевая звезда — фирменный знак Gemini.
///
/// Встречается в макете постоянно: логотип на splash, иконка в кнопке Pro,
/// маркеры списка на пейволе, счётчик токенов. Поэтому это форма, а не картинка:
/// она масштабируется без потерь и красится в любой цвет.
///
/// Лучи строятся квадратичными кривыми с общей контрольной точкой в центре —
/// именно это даёт вогнутые стороны, а не прямые как у обычной звезды.
struct SparkleShape: Shape {
    /// Насколько «вогнуты» стороны: 0 — ромб с прямыми гранями, 1 — предельно тонкие лучи.
    var concavity: CGFloat = 0.82

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        // Чем больше вогнутость, тем ближе контрольная точка к центру.
        let controlX = center.x + radiusX * (1 - concavity)
        let controlY = center.y + radiusY * (1 - concavity)

        let top = CGPoint(x: center.x, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: center.y)
        let bottom = CGPoint(x: center.x, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: center.y)

        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: right, control: CGPoint(x: controlX, y: center.y - radiusY * (1 - concavity)))
        path.addQuadCurve(to: bottom, control: CGPoint(x: controlX, y: controlY))
        path.addQuadCurve(to: left, control: CGPoint(x: center.x - radiusX * (1 - concavity), y: controlY))
        path.addQuadCurve(to: top, control: CGPoint(
            x: center.x - radiusX * (1 - concavity),
            y: center.y - radiusY * (1 - concavity)
        ))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        let markSparkle = AppMetrics.appMarkLarge * AppMetrics.appMarkSparkleRatio

        SparkleShape()
            .fill(AppColor.accent)
            .frame(width: markSparkle, height: markSparkle)
        SparkleShape().fill(AppColor.textPrimary).frame(width: AppMetrics.icon, height: AppMetrics.icon)
    }
    .padding(40)
    .background(AppColor.bgPrimary)
}
