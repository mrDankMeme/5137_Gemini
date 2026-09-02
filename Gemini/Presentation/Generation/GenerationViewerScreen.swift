import AVKit
import SwiftUI

/// Просмотр готовой генерации: фото или видео и ряд действий под ним.
///
/// Сохранение в библиотеку в макете стоит токенов, поэтому цена подписана прямо
/// на кнопке. Списание подтверждает сервер — локальный баланс не является
/// источником правды и не открывает доступ сам по себе.
struct GenerationViewerScreen: View {
    let item: LibraryItem
    var isSaving = false
    /// Только что сохранена — кнопка на пару секунд показывает галочку вместо
    /// иконки, а не просто гаснущий спиннер: загрузка ролика может идти
    /// долго, и без этого отклика непонятно, сработало сохранение или нет.
    var isSaved = false
    /// Файл ещё скачивается для отправки — кнопка показывает ход.
    var isSharing = false

    let onBack: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    /// Повтор генерации. `nil` — повторять нечем: у библиотеки нет исходного
    /// запроса, пока backend его не отдаёт. Кнопка тогда видна, но неактивна:
    /// живая кнопка, которая ничего не делает, читается как поломка.
    var onRegenerate: (() -> Void)?
    let onShowInChat: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPresented = false
    /// Плеер живёт ровно столько, сколько открыт экран, и не пересоздаётся
    /// на каждую перерисовку — иначе воспроизведение сбрасывалось бы в начало.
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "") {
                CircleIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Back",
                    action: onBack
                )
            }

            preview
                .padding(.horizontal, AppMetrics.screenPadding)
                // В макете между навбаром и картинкой 22 pt.
                .padding(.top, 22)

            Spacer(minLength: 16)

            actions
                .padding(.horizontal, AppMetrics.screenPadding)
                // В макете ряд действий кончается на 824, а зона домашнего
                // индикатора начинается с 840 — то есть зазор 16, а не 8.
                .padding(.bottom, AppMetrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgPrimary)
        // Тексты из макета: удаление необратимо, поэтому спрашиваем подтверждение.
        .alert("Delete photo?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This action cannot be undone")
        }
    }

    /// Пока файла нет, показываем ровную подложку того же размера — так экран
    /// не прыгает, когда подключится настоящая загрузка.
    @ViewBuilder
    private var preview: some View {
        // Видео здесь именно проигрывается. Раньше и тут стоял `GenerationPreview`
        // с треугольником поверх пустоты: ролик генерировался, списывались
        // кредиты, а посмотреть его было нельзя — кнопка воспроизведения не
        // делала ничего.
        if item.kind == .video, let url = item.url {
            VideoPlayer(player: player)
                .aspectRatio(370.0 / 554.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.xs))
                .accessibilityLabel("Video")
                // Плеер заводится здесь, а не в теле вью: присваивание
                // состояния во время отрисовки SwiftUI считает ошибкой
                // («Modifying state during view update») и ведёт себя как
                // хочет. `task(id:)` привязан к ссылке — новый ролик получит
                // свой плеер, а перерисовки прежний не пересоздают.
                .task(id: url) {
                    guard player == nil else { return }
                    player = AVPlayer(url: url)
                }
        } else {
            // Числа из макета: кружок 56, глиф 20, подложка `#1E1E1E` 50%.
            GenerationPreview(item: item)
                .aspectRatio(370.0 / 554.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.xs))
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.xs) {
            action(
                isSaved ? "checkmark" : "square.and.arrow.down",
                title: isSaved ? "Saved" : "Save",
                isInFlight: isSaving,
                run: onSave
            )
            action("square.and.arrow.up", title: "Share", isInFlight: isSharing, run: onShare)
            action(
                "arrow.trianglehead.2.clockwise.rotate.90",
                title: "Regenerate",
                isEnabled: onRegenerate != nil
            ) { onRegenerate?() }
            action("bubble.left.and.bubble.right", title: "Show in Chat", run: onShowInChat)
            action("trash", title: "Delete") { isDeleteConfirmationPresented = true }
        }
        .frame(maxWidth: .infinity)
    }

    /// `LocalizedStringKey`, а не `String`: подписи кнопок — всегда литералы,
    /// а `Text(String)` их не переводит.
    private func action(
        _ systemImage: String,
        title: LocalizedStringKey,
        isInFlight: Bool = false,
        isEnabled: Bool = true,
        run: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            Button(action: run) {
                ZStack {
                    Circle().fill(AppColor.accent)

                    if isInFlight {
                        ProgressView().tint(AppColor.textPrimary)
                    } else {
                        Image(systemName: systemImage)
                            // 16, как в макете у save / share / replace / trash.
                            .font(AppFont.Icon.medium)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .frame(width: AppMetrics.playButton, height: AppMetrics.playButton)
                .overlay(Circle().strokeBorder(AppColor.strokeSecondary, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isInFlight || !isEnabled)
            .opacity(isEnabled ? 1 : 0.4)

            Text(title)
                .appTextStyle(AppFont.actionCaption)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

#Preview("Image") {
    GenerationViewerScreen(
        item: LibraryItem(id: "1", kind: .image, url: nil),
        onBack: {}, onSave: {}, onShare: {}, onShowInChat: {}, onDelete: {}
    )
}

#Preview("Video") {
    GenerationViewerScreen(
        item: LibraryItem(id: "2", kind: .video, url: nil),
        onBack: {}, onSave: {}, onShare: {}, onShowInChat: {}, onDelete: {}
    )
}
