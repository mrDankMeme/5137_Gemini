import SwiftUI

/// Выпадающий список моделей под чипом в шапке.
struct ModelPickerMenu: View {
    let models: [AIModel]
    let selectedID: AIModel.ID
    let onSelect: (AIModel) -> Void

    var body: some View {
        ScrollView {
            modelsList
        }
        // Список моделей приходит с backend, и длина его неизвестна: без ограничения
        // высоты нижние строки уезжают за экран и нажать их нечем.
        .frame(maxHeight: AppMetrics.modelMenuMaxHeight)
        .scrollBounceBehavior(.basedOnSize)
        // Ширина, скругление и шаг — из макета: 260×331, радиус 32, шаг 12.
        .frame(width: AppMetrics.modelMenuWidth, alignment: .leading)
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.xl))
        // Обводка есть и в макете: без неё меню сливается с тёмным фоном,
        // когда под ним лежит не чёрный экран, а свечение.
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
        )
        // Радиус вдвое меньше фигмовского: layer blur в Figma примерно вдвое
        // крупнее гауссова радиуса SwiftUI — то же соотношение, что у арта.
        // Из макета: чёрная 20%, размытие 24 (радиус вдвое меньше), сдвиг 16.
        .shadow(color: .black.opacity(0.2), radius: 12, y: 16)
    }

    private var modelsList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(models) { model in
                Button {
                    onSelect(model)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(model.title)
                            .appTextStyle(AppFont.captionMedium)
                            .foregroundStyle(AppColor.textPrimary)

                        Text(model.subtitle)
                            .appTextStyle(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.id == selectedID ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ModelPickerMenu(models: PreviewData.models, selectedID: "gemini-2.5-flash") { _ in }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
}
