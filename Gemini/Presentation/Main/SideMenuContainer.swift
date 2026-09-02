import SwiftUI
import UIKit

/// Боковое меню во всю ширину: содержимое уезжает вправо целиком, на его место
/// приходит меню.
///
/// Сделано по 5142 (`MainPager`), а не по 232: в макете меню занимает весь экран,
/// и «язычок» оставшегося чата справа был бы отсебятиной. Отсюда же и отличия
/// от 232 — не нужны ни затемняющая плашка, ни скругление уехавшего экрана,
/// ни тень: контент уходит за край полностью и не участвует в кадре.
///
/// Меню — **не модальное окно**. Пока оно было `fullScreenCover`, с него
/// не поднималась ни одна шторка: UIKit отказывается презентовать с контроллера,
/// который сам уже презентует.
struct SideMenuContainer<MenuContent: View, Content: View>: View {
    /// Выключается на вложенных экранах: там правый свайп принадлежит возврату
    /// назад, а не меню. Иначе два жеста спорят за одно движение.
    var isEnabled = true

    @Binding var isExpanded: Bool
    @ViewBuilder var menuContent: () -> MenuContent
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pageWidth: CGFloat = 0
    @State private var shift: CGFloat = 0
    @State private var isDragging = false
    @State private var dragStart: CGFloat = 0
    @State private var haptics = false

    var body: some View {
        ZStack(alignment: .leading) {
            menuContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: -pageWidth + shift)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: shift)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            pageWidth = width
            snapToState()
        }
        .gesture(
            SideMenuDragGesture(
                canDragRight: isEnabled && !isExpanded,
                canDragLeft: isEnabled && isExpanded,
                handle: handleDrag
            )
        )
        // Отклик мягкий и **только на смену состояния**: доведённый до конца
        // и брошенный на полпути жест не должны отзываться одинаково.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: haptics)
        .onChange(of: isExpanded, initial: true) { _, _ in
            withAnimation(animation) { snapToState() }
        }
    }

    /// Возвращает сдвиг туда, где ему велит быть состояние: для нажатий на кнопку
    /// и крестик и для смены ширины. Во время жеста не трогается — там сдвигом
    /// владеет палец.
    private func snapToState() {
        guard !isDragging else { return }
        shift = isExpanded ? pageWidth : 0
    }

    private func handleDrag(_ recognizer: UIPanGestureRecognizer) {
        // Ширина ещё не измерена — двигать нечего, а деление на неё дало бы NaN.
        guard pageWidth > 0 else { return }

        let translation = recognizer.translation(in: recognizer.view).x
        // Скорость учитывается, чтобы короткий резкий бросок доводил меню
        // до конца, не доходя пальцем до середины экрана.
        let velocity = recognizer.velocity(in: recognizer.view).x / 5

        switch recognizer.state {
        case .began, .changed:
            if !isDragging {
                isDragging = true
                dragStart = shift
            }
            shift = min(max(dragStart + translation, 0), pageWidth)
        default:
            isDragging = false
            withAnimation(animation) {
                setExpanded(shift + velocity > pageWidth / 2)
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        if isExpanded != expanded { haptics.toggle() }
        shift = expanded ? pageWidth : 0
        isExpanded = expanded
    }

    /// «Уменьшение движения» отменяет пружину: жест по-прежнему следует за пальцем,
    /// но полноэкранный отскок — ровно то движение, которое эта настройка просит убрать.
    private var animation: Animation? {
        reduceMotion ? nil : .interactiveSpring(duration: 0.3, extraBounce: 0.02)
    }
}

/// Панорамирование, которое уступает горизонтальным скроллам под пальцем.
private struct SideMenuDragGesture: UIGestureRecognizerRepresentable {
    var canDragRight: Bool
    var canDragLeft: Bool
    var handle: (UIPanGestureRecognizer) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        gesture.maximumNumberOfTouches = 1
        return gesture
    }

    func updateUIGestureRecognizer(_: UIPanGestureRecognizer, context: Context) {
        // Разрешённые направления меняются вместе с состоянием меню,
        // а координатор живёт дольше этой структуры.
        context.coordinator.parent = self
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context _: Context) {
        handle(recognizer)
    }

    func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SideMenuDragGesture

        init(parent: SideMenuDragGesture) {
            self.parent = parent
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = pan.velocity(in: pan.view)
            // Вертикальные движения достаются ленте сообщений.
            guard abs(velocity.x) > abs(velocity.y) else { return false }

            return velocity.x > 0 ? parent.canDragRight : parent.canDragLeft
        }

        /// Уступаем горизонтальному скроллу, пока у него есть куда ехать в сторону
        /// жеста: лента источников, листинг кода, подсказки в поле ввода. Меню
        /// забирает движение только когда скролл упёрся в край.
        ///
        /// Именно `shouldRequireFailureOf`, а не зеркальный `shouldBeRequiredToFailBy`:
        /// имена читаются буквально, и зеркальный говорит обратное — что скролл ждёт
        /// меню. В 5142 с зеркальным вариантом чипы прокручивались в одну сторону
        /// и отказывались возвращаться.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let scrollView = otherGestureRecognizer.view as? UIScrollView,
                  scrollView.contentSize.width > scrollView.bounds.width
            else {
                return false
            }

            let offset = scrollView.contentOffset.x

            // Палец влево — скролл едет к концу, место есть пока не упёрлись в дальний
            // край. Палец вправо — к началу, а начало это `-contentInset.left`,
            // а не ноль: сравнение с нулём считало бы «уже дома» при живом отступе.
            guard pan.velocity(in: pan.view).x < 0 else {
                return offset > -scrollView.adjustedContentInset.left
            }

            let maxOffset = scrollView.contentSize.width
                - scrollView.bounds.width
                + scrollView.adjustedContentInset.right
            return offset < maxOffset
        }
    }
}
