import SwiftUI
import UIKit

/// Размытие фона под собой без светлой подложки, которую даёт обычный
/// `UIVisualEffectView` на тёмной теме, — снимает системный цветной фильтр
/// со слоя, оставляя только сам блюр. Порт из 232, без правок.
struct TransparentBlurView: UIViewRepresentable {
    func makeUIView(context _: Context) -> CustomBlurView {
        let view = CustomBlurView(effect: .init(style: .systemUltraThinMaterial))
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_: CustomBlurView, context _: Context) {}
}

final class CustomBlurView: UIVisualEffectView {
    init(effect: UIBlurEffect) {
        super.init(effect: effect)
        setup()
    }

    func setup() {
        removeFilters()

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            DispatchQueue.main.async {
                self.removeFilters()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func removeFilters() {
        if let filterLayer = layer.sublayers?.first {
            filterLayer.filters = []
        }
    }
}
