import BroadUIFlows
import SwiftUI

/// Онбординг по макету: полноэкранный арт, затемнение снизу, заголовок,
/// подзаголовок, кнопка Continue и юридическая строка.
///
/// Логика — из `OnboardingViewModel` платформы: он держит текущий слайд,
/// правило ATT (`afterFirstSlide`) и переход дальше. Вью только рисует.
struct OnboardingScreen: View {
    /// Модель создана и живёт в `AppCompositionRoot`. `@StateObject` здесь был бы
    /// ошибкой: он объявляет владение и навсегда запоминает первый переданный объект,
    /// а сигналы жизненного цикла ушли бы в него же, даже если владелец пересоздан.
    @ObservedObject var viewModel: OnboardingViewModel
    let onFinished: () -> Void
    let onOpenLink: (OnboardingFooterDestination) -> Void
    let onRestore: () -> Void
    var isRestoring = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bottomBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Арт — фоном, а не слоем стека. В `ZStack` он уходил под статус-бар,
        // стек принимал его высоту 874 внутри безопасной области 781, и нижний
        // блок уезжал вниз на разницу: кнопка вставала на 51 pt ниже макета,
        // а юридическая строка залезала на индикатор home.
        .background { artwork.ignoresSafeArea() }
        .background(AppColor.bgPrimary)
        // Платформа показывает запрос ATT, только когда сошлись все признаки:
        // онбординг виден, виден первый слайд, приложение активно и окно на экране.
        // `isApplicationActive` и `isWindowVisible` по умолчанию false, поэтому без
        // этих двух вызовов системный запрос не появится никогда.
        .onAppear {
            viewModel.onboardingDidAppear()
            viewModel.windowVisibilityDidChange(true)
            viewModel.applicationActiveDidChange(scenePhase == .active)
            if viewModel.completeInvalidConfigurationIfNeeded() { onFinished() }
        }
        .onDisappear {
            viewModel.windowVisibilityDidChange(false)
            viewModel.onboardingDidDisappear()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.applicationActiveDidChange(phase == .active)
        }
    }

    /// Арт слайда. У него есть `id`, иначе при смене слайда SwiftUI переиспользует
    /// прежнее изображение и перехода не видно.
    @ViewBuilder
    private var artwork: some View {
        if let page = viewModel.currentPage {
            Image(page.media.identifier)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .id(page.id)
                .transition(.opacity)
                .accessibilityHidden(true)
        } else {
            AppColor.bgPrimary
        }
    }

    private var bottomBlock: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text(viewModel.currentPage?.title ?? "")
                    .appTextStyle(AppFont.h2)
                    .foregroundStyle(AppColor.textPrimary)

                if let subtitle = viewModel.currentPage?.subtitle {
                    Text(subtitle)
                        .appTextStyle(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Spacing.xs) {
                PrimaryButton(
                    title: viewModel.isLastPage
                        ? viewModel.configuration.completionTitle
                        : viewModel.configuration.continueTitle
                ) {
                    advance()
                }

                LegalFooter(
                    onPrivacyPolicy: { onOpenLink(.privacyPolicy) },
                    onRestore: onRestore,
                    onTermsOfUse: { onOpenLink(.termsOfUse) },
                    isRestoring: isRestoring,
                    // В онбординге строка белая, приглушена она только на пейволах.
                    tint: AppColor.textPrimary
                )
            }
        }
        .padding(.top, Spacing.xxl)
        .padding(.horizontal, AppMetrics.screenPadding)
        .frame(maxWidth: .infinity)
        .bottomScrim(solidAt: 0.5)
        // Первый слайд сообщает о себе отдельно: по нему платформа решает,
        // когда законно показать системный запрос ATT.
        .onAppear {
            if viewModel.currentIndex == 0 { viewModel.firstSlideDidAppear() }
        }
        .motionAwareAnimation(.easeInOut(duration: 0.25), value: viewModel.currentIndex)
    }

    private func advance() {
        // `advance()` возвращает true, когда онбординг закончился: слайдов больше нет
        // либо конфигурация невалидна. false означает, что показан следующий слайд.
        // Гасить первый слайд вручную не нужно — `advance()` сам снимает признак
        // видимости и отменяет запланированный запрос ATT.
        if viewModel.advance() {
            onFinished()
        }
    }
}
