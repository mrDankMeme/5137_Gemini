import SwiftUI

/// Раскладки поля ввода: три одних и тех же вью, две расстановки.
///
/// Свёрнуто (`main--home`) — одна строка: кнопки слева, текст, кнопки справа;
/// это обычный `HStackLayout`. Развёрнуто (`main--home-4`) — текст занимает
/// строку во всю ширину, кнопки уходят под него отдельным рядом; это
/// `ComposerExpandedLayout` ниже.
///
/// Переключаются они через `AnyLayout`, и это принципиально. Раньше была одна
/// раскладка с параметром `isExpanded`, и переход выходил рывком: **свой
/// `Layout` SwiftUI не анимирует** — параметр меняется, расстановка
/// пересчитывается мгновенно, и серая подсказка прыгала на месте. `AnyLayout`
/// же анимируется системой: те же вью переезжают из одной расстановки
/// в другую, а не подменяются.
struct ComposerExpandedLayout: Layout {
    /// Зазор между текстом и рядом кнопок.
    var rowSpacing: CGFloat

    /// Порядок вью задан вызывающей стороной: слева, текст, справа.
    private enum Index {
        static let leading = 0
        static let text = 1
        static let trailing = 2
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let width = proposal.replacingUnspecifiedDimensions().width
        let leading = subviews[Index.leading].sizeThatFits(.unspecified)
        let trailing = subviews[Index.trailing].sizeThatFits(.unspecified)
        let text = subviews[Index.text].sizeThatFits(
            ProposedViewSize(width: width, height: nil)
        )
        return CGSize(
            width: width,
            height: text.height + rowSpacing + max(leading.height, trailing.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        guard subviews.count == 3 else { return }
        let leading = subviews[Index.leading].sizeThatFits(.unspecified)
        let trailing = subviews[Index.trailing].sizeThatFits(.unspecified)
        let text = subviews[Index.text].sizeThatFits(
            ProposedViewSize(width: bounds.width, height: nil)
        )

        subviews[Index.text].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: bounds.width, height: text.height)
        )

        let rowY = bounds.minY + text.height + rowSpacing
        subviews[Index.leading].place(
            at: CGPoint(x: bounds.minX, y: rowY),
            proposal: ProposedViewSize(leading)
        )
        subviews[Index.trailing].place(
            at: CGPoint(x: bounds.maxX - trailing.width, y: rowY),
            proposal: ProposedViewSize(trailing)
        )
    }
}
