import UIKit

extension UIImage {
    /// Готовит снимок к отправке: уменьшает и жмёт в JPEG.
    ///
    /// Тот же рецепт, что в 232, и он обязателен: пикер фотографий отдаёт HEIC,
    /// а бэкенд принимает только `image/jpeg`, `png`, `gif`, `webp` — HEIC
    /// он отвергает. Плюс исходник с камеры весит десятки мегабайт, а base64
    /// раздувает его ещё на треть.
    ///
    /// `maxDimension` 1568 — предел, после которого модель всё равно ужимает
    /// картинку сама; качество снижается ступенями, пока не уложимся в лимит.
    nonisolated func preparedForUpload(
        maxDimension: CGFloat = 1568,
        maxBytes: Int = 9 * 1024 * 1024
    ) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let resized: UIImage
        if scale < 1 {
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            resized = UIGraphicsImageRenderer(size: target).image { _ in
                draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            resized = self
        }

        var quality: CGFloat = 0.85
        var data = resized.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.2 {
            quality -= 0.15
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }
}
