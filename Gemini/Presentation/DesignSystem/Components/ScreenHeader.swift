import SwiftUI

/// Шапка экрана: кнопка слева, центральный элемент и кнопка справа.
///
/// Центр выравнивается по середине **экрана**, а не между кнопками — иначе он
/// съезжает, когда слева и справа стоят элементы разной ширины (кнопка Pro и крестик
/// в меню, гамбургер и баланс токенов на главном).
///
/// В макете навбар занимает 138 pt: статус-бар 62, отступ 16, ряд 44 и ещё 16 снизу.
struct ScreenHeader<Center: View, Leading: View, Trailing: View>: View {
    @ViewBuilder var center: Center
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @State private var leadingWidth: CGFloat = 0
    @State private var trailingWidth: CGFloat = 0

    /// Поле, которое центр обязан оставить кнопкам с каждой стороны.
    ///
    /// Меряется, а не задаётся числом: кнопки растут вместе с системным шрифтом,
    /// и фиксированное поле «под 44 pt» на крупных размерах заводит заголовок
    /// прямо под кнопку.
    private var sideInset: CGFloat {
        max(leadingWidth, trailingWidth) + 8
    }

    var body: some View {
        ZStack {
            center
                .padding(.horizontal, sideInset)

            HStack {
                leading
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingWidth = $0 }
                Spacer(minLength: 8)
                trailing
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingWidth = $0 }
            }
        }
        .frame(minHeight: AppMetrics.tapTarget)
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.top, Spacing.reg)
        .padding(.bottom, Spacing.reg)
        .background {
            LinearGradient(
                colors: [AppColor.bgPrimary, AppColor.bgPrimary.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .contain)
    }
}

extension ScreenHeader where Center == ScreenHeaderTitle {
    /// Шапка с обычным текстовым заголовком.
    init(
        title: String,
        titleStyle: AppTextStyle = AppFont.h4,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            center: { ScreenHeaderTitle(title: title, style: titleStyle) },
            leading: leading,
            trailing: trailing
        )
    }
}

extension ScreenHeader where Center == ScreenHeaderTitle, Trailing == EmptyView {
    init(title: String, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, leading: leading, trailing: { EmptyView() })
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(@ViewBuilder center: () -> Center, @ViewBuilder leading: () -> Leading) {
        self.init(center: center, leading: leading, trailing: { EmptyView() })
    }
}

/// Заголовок в шапке. Поля по бокам ему задаёт сама шапка — по ширине кнопок.
struct ScreenHeaderTitle: View {
    let title: String
    /// У чата заголовок мельче: в макете это название переписки 14 pt regular,
    /// а не заголовок экрана.
    var style: AppTextStyle = AppFont.h4

    var body: some View {
        Text(title)
            .appTextStyle(style)
            .foregroundStyle(AppColor.textPrimary)
            .lineLimit(1)
    }
}

/// Шапка с одной кнопкой «назад» — самый частый случай в макете.
struct BackHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ScreenHeader(title: title) {
            CircleIconButton(
                systemImage: "chevron.left",
                accessibilityLabel: "Back",
                action: onBack
            )
        }
    }
}
