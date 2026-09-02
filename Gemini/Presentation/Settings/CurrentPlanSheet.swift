import SwiftUI

/// Шторка «Current plan»: тариф, срок и отмена подписки.
///
/// Отмена — необратимое действие с деньгами, поэтому она всегда спрашивает
/// подтверждение, а сама операция уйдёт в use case платформы, когда подключим Adapty.
struct CurrentPlanSheet: View {
    let planName: String
    /// `nil` — срока нет: у бесплатного тарифа его не бывает, а у активной
    /// подписки платформа может его не назвать. Выдумывать дату нельзя.
    let periodDescription: String?
    /// Есть ли что отменять. У бесплатного тарифа кнопки отмены нет.
    var canCancel = true
    var isCancelling = false

    let onCancelSubscription: () -> Void

    @State private var isConfirmationPresented = false
    /// Высота содержимого. Фиксированная высота из макета посчитана для
    /// подписчика — со сроком и кнопкой отмены. На бесплатном тарифе их нет,
    /// и шторка открывалась наполовину пустой.
    @State private var contentHeight: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Current plan")
                    .appTextStyle(AppFont.h4)
                    .foregroundStyle(AppColor.textPrimary)

                row(title: "Tariff plan", value: planName)
                // Строка со сроком исчезает целиком, а не показывает прочерк:
                // у бесплатного тарифа срока не существует.
                if let periodDescription {
                    row(title: "Subscription period", value: periodDescription)
                }
            }

            // Отменять нечего, пока подписки нет: на бесплатном тарифе красная
            // кнопка «Cancel subscription» — обещание действия, которого не будет.
            if canCancel {
                Button {
                    isConfirmationPresented = true
                } label: {
                    ZStack {
                        Text("Cancel subscription")
                            .appTextStyle(AppFont.button)
                            .foregroundStyle(AppColor.destructive)
                            .opacity(isCancelling ? 0 : 1)

                        if isCancelling {
                            ProgressView().tint(AppColor.destructive)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppMetrics.sheetButtonHeight)
                    .background(AppColor.bgElevated, in: .rect(cornerRadius: Radius.xl))
                }
                .buttonStyle(.plain)
                .disabled(isCancelling)
            }
        }
        .padding(.horizontal, Spacing.lg)
        // Сверху 40 — под полоску захвата, как в макете.
        .padding(.top, 40)
        .padding(.bottom, Spacing.reg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .background(AppColor.bgSecondary)
        .presentationDetents([.height(contentHeight ?? AppMetrics.currentPlanSheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColor.bgSecondary)
        .presentationCornerRadius(AppMetrics.sheetRadius)
        .alert("Are you sure you want to cancel your PRO subscription?", isPresented: $isConfirmationPresented) {
            Button("Stay On Pro", role: .cancel) {}
            Button("Cancel subscription", role: .destructive, action: onCancelSubscription)
        }
    }

    // `LocalizedStringKey` у заголовка: он всегда литерал. Значение приходит
    // из данных подписки и переводу не подлежит.
    private func row(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .appTextStyle(AppFont.rowValue)
                .foregroundStyle(AppColor.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .appTextStyle(AppFont.rowValue)
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(minHeight: AppMetrics.menuRow)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        CurrentPlanSheet(
            planName: "PRO",
            periodDescription: "until 25 April 2026",
            onCancelSubscription: {}
        )
    }
}
