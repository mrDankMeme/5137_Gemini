import SwiftUI

/// Раскладка чипов: переносит их по строкам и центрирует каждую строку.
///
/// В макете чипы-подсказки стоят двумя колонками неравной ширины, и каждая строка
/// выровнена по центру — обычный `HStack` так не умеет, а `Grid` ломает разную ширину.
struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        // `proposal.width` бывает не задан — например при `fixedSize` или при
        // измерительном проходе. Без замены на конечное число сюда уходит
        // бесконечная ширина, и все чипы складываются в одну строку.
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height + (total > 0 ? verticalSpacing : 0)
        }
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(maxWidth, width), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        // Раскладываем по фактическим границам: родитель мог дать меньше, чем
        // мы просили, и тогда разбиение по предложению не совпало бы с местом.
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY

        for row in rows {
            // Строка центрируется целиком, как в макете. `max(0, …)` нужен для
            // случая, когда один чип шире строки: иначе он вылезет за оба края.
            var x = bounds.minX + max(0, (bounds.width - row.width) / 2)
            for item in row.items {
                var size = subviews[item].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                // Один длинный чип не должен вылезать за правый край: ограничиваем
                // его шириной строки.
                size.width = min(size.width, bounds.width)
                subviews[item].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            // Предлагаем ширину строки, чтобы длинная подпись могла ужаться,
            // а не вылезти за экран.
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let widthWithItem = current.items.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width

            if !current.items.isEmpty, widthWithItem > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.width = current.items.isEmpty ? size.width : current.width + horizontalSpacing + size.width
            current.height = max(current.height, size.height)
            current.items.append(index)
        }

        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
