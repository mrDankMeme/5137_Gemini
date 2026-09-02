import SwiftUI

/// Готовая генерация: сама картинка (или кадр видео) и кнопка воспроизведения.
///
/// В макете у плиток библиотеки и у карточки в переписке заливка изображением,
/// а не ровная подложка. Раньше все три места рисовали заглушку и не трогали
/// `url` — библиотека выглядела сеткой пустых квадратов, даже когда файлы есть.
///
/// Подложка остаётся под картинкой: пока файл грузится, сетка не должна прыгать.
struct GenerationPreview: View {
    let item: LibraryItem
    /// Размер кнопки воспроизведения: в библиотеке 56 (`menu--menu-5`),
    /// в переписке карточка крупнее.
    var playSize: CGFloat = AppMetrics.playButton

    /// Кадр видео. `AsyncImage` умеет только картинки, а сервер постера
    /// не отдаёт — до этого готовый ролик выглядел пустой подложкой.
    @State private var frame: CGImage?

    var body: some View {
        Color.clear
            .overlay {
                if let url = item.url {
                    if item.kind == .video {
                        videoFrame(url)
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView().tint(AppColor.textSecondary)
                        }
                    }
                }
            }
            .overlay {
                if item.kind == .video {
                    Image(systemName: "play.fill")
                        .font(AppFont.Icon.xLarge)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: playSize, height: playSize)
                        // `#1E1E1E 50%` из макета — раньше в двух местах стояли
                        // два разных литерала мимо токена.
                        .background(AppColor.playBackdrop, in: .circle)
                }
            }
            .background(AppColor.bgSecondary)
            .accessibilityElement()
            .accessibilityLabel(item.kind == .video ? "Video" : "Image")
    }

    @ViewBuilder
    private func videoFrame(_ url: URL) -> some View {
        if let frame {
            Image(decorative: frame, scale: 1)
                .resizable()
                .scaledToFill()
        } else {
            ProgressView()
                .tint(AppColor.textSecondary)
                .task(id: url) { frame = await VideoThumbnailLoader.shared.thumbnail(for: url) }
        }
    }
}
