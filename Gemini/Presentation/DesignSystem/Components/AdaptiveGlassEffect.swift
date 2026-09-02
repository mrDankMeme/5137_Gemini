import SwiftUI

extension View {
    /// Настоящее стекло на iOS 26, а до неё — свой блюр под тем же видом:
    /// приглушённая тёмная заливка, `TransparentBlurView` под ней и тонкая
    /// светлая обводка по диагонали. Порт из 232 (`Backports.swift`).
    @ViewBuilder
    func adaptiveGlassEffect(in shape: some InsettableShape = RoundedRectangle(cornerRadius: Radius.sm)) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background {
                AppColor.bgPrimary.opacity(0.4)
                TransparentBlurView()
                    .blur(radius: 5, opaque: true)
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppColor.strokePrimary,
                                AppColor.strokePrimary.opacity(0.2),
                                AppColor.strokePrimary.opacity(0.2),
                                AppColor.strokePrimary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .contentShape(shape)
        }
    }
}
