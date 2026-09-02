import AVFoundation
import CoreGraphics
import Foundation

/// Кадр из видео для плитки и карточки в переписке.
///
/// Сервер отдаёт только сам файл — ни превью, ни постера в задаче генерации
/// нет (`assets` содержит один `video/mp4`). А `AsyncImage` видео не декодирует
/// вовсе: до этого карточка готового ролика оставалась пустой подложкой
/// с треугольником, и человек, отдавший 14 кредитов, видел ровно ничего.
///
/// Кадр берётся первый, что дальше нуля: у многих роликов самый первый — чёрный.
/// Результат держится в памяти: сетка библиотеки перерисовывается при каждой
/// прокрутке, и вытаскивать кадр заново на каждый показ — впустую жечь батарею.
actor VideoThumbnailLoader {
    static let shared = VideoThumbnailLoader()

    private var cache: [URL: CGImage] = [:]
    private var inFlight: [URL: Task<CGImage?, Never>] = [:]

    func thumbnail(for url: URL) async -> CGImage? {
        if let cached = cache[url] {
            return cached
        }
        if let running = inFlight[url] {
            return await running.value
        }

        let task = Task<CGImage?, Never> {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            // Кадр не обязан быть точным до миллисекунды — точный поиск
            // заставляет декодировать всё до ключевого кадра.
            generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            return try? await generator.image(at: time).image
        }
        inFlight[url] = task

        let image = await task.value
        inFlight[url] = nil
        if let image {
            cache[url] = image
        }
        return image
    }
}
