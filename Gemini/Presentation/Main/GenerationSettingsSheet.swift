import SwiftUI

/// Шторка параметров генерации: пропорции, разрешение и — для видео — звук и длительность.
struct GenerationSettingsSheet: View {
    /// У видео появляются две дополнительные секции.
    let includesVideoOptions: Bool
    /// Модель принимает ступени качества. Kling, например, не принимает
    /// никаких — показывать ему выбор значило бы предлагать настройку,
    /// которая ни на что не влияет.
    var showsResolution = true
    @Binding var settings: GenerationSettings
    let onApply: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                section("Aspect ratio") {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(GenerationSettings.AspectRatio.allCases) { ratio in
                            option(
                                ratio.title,
                                isSelected: settings.aspectRatio == ratio,
                                previewRatio: ratio.previewRatio
                            ) {
                                settings.aspectRatio = ratio
                            }
                        }
                    }
                }

                if showsResolution {
                    section("Resolution") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(GenerationSettings.Resolution.allCases) { resolution in
                                option(resolution.title, isSelected: settings.resolution == resolution) {
                                    settings.resolution = resolution
                                }
                            }
                        }
                    }
                }

                if includesVideoOptions {
                    section("Sound") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            option(String(localized: "On"), isSelected: settings.isSoundOn) { settings.isSoundOn = true }
                            option(String(localized: "Off"), isSelected: !settings.isSoundOn) { settings.isSoundOn = false }
                        }
                    }

                    section("Duration") {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(GenerationSettings.Duration.allCases) { duration in
                                option(duration.title, isSelected: settings.duration == duration) {
                                    settings.duration = duration
                                }
                            }
                        }
                    }
                }

                PrimaryButton(title: String(localized: "Apply"), action: onApply)
                    .frame(height: AppMetrics.sheetButtonHeight)
            }
            .padding(.horizontal, Spacing.lg)
            // В макете у шторки сверху 40 (под полоску захвата), снизу 16.
            .padding(.top, 40)
            .padding(.bottom, Spacing.reg)
        }
        .background(AppColor.bgSecondary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.bgSecondary)
        .presentationCornerRadius(AppMetrics.sheetRadius)
    }

    // `LocalizedStringKey`: заголовки разделов — литералы.
    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .appTextStyle(AppFont.h4)
                .foregroundStyle(AppColor.textPrimary)

            content()
        }
    }

    /// Размер рамки-превью пропорций. Площадь постоянная, кроме квадрата —
    /// так нарисовано в макете, см. `AppMetrics.ratioIconArea`.
    private func ratioIconSize(_ ratio: Double) -> (width: CGFloat, height: CGFloat) {
        guard abs(ratio - 1) > 0.01 else {
            return (AppMetrics.ratioIconSquare, AppMetrics.ratioIconSquare)
        }
        let area = Double(AppMetrics.ratioIconArea)
        return (CGFloat((area * ratio).squareRoot()), CGFloat((area / ratio).squareRoot()))
    }

    /// Вариант выбора. Невыбранный — чёрный, выбранный — акцент на половине
    /// прозрачности с обводкой, как в макете.
    private func option(
        _ title: String,
        isSelected: Bool,
        previewRatio: Double? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let previewRatio {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(AppColor.textPrimary, lineWidth: 1.5)
                        .frame(
                            width: ratioIconSize(previewRatio).width,
                            height: ratioIconSize(previewRatio).height
                        )
                        .frame(width: AppMetrics.icon, height: AppMetrics.icon)
                }

                Text(title)
                    .appTextStyle(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.optionRow)
            .background(
                isSelected ? AppColor.accent.opacity(0.5) : AppColor.bgPrimary,
                in: .rect(cornerRadius: Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.accent : .clear, lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var settings = GenerationSettings()

    Color.black.sheet(isPresented: .constant(true)) {
        GenerationSettingsSheet(includesVideoOptions: true, settings: $settings, onApply: {})
    }
}
