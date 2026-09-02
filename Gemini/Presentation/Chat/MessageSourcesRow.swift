import SwiftUI

/// Источники под ответом с поиском в интернете.
///
/// Показывается только когда они есть: у обычного ответа источников нет и быть
/// не может, а пустой блок читался бы как «поиск ничего не нашёл».
struct MessageSourcesRow: View {
    let sources: [MessageSource]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Sources", systemImage: "globe")
                .appTextStyle(AppFont.disclaimer)
                .foregroundStyle(AppColor.textTertiary)

            // Горизонтальная лента, а не столбик: источников бывает и десяток,
            // и они не должны отодвигать следующий ответ на экран вниз.
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(sources) { source in
                        chip(for: source)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func chip(for source: MessageSource) -> some View {
        Button {
            openURL(source.url)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(source.title)
                    .appTextStyle(AppFont.captionMedium)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(source.host)
                    .appTextStyle(AppFont.disclaimer)
                    .foregroundStyle(AppColor.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 10)
            .frame(width: AppMetrics.sourceChipWidth, alignment: .leading)
            .frame(minHeight: AppMetrics.tapTarget)
            .background(AppColor.bgSecondary, in: .rect(cornerRadius: Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(source.title), \(source.host)"))
    }
}

#Preview {
    MessageSourcesRow(sources: PreviewData.sources)
        .padding(AppMetrics.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
}
