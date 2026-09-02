import Foundation

/// Готовый файл генерации на диске.
///
/// И «Поделиться», и «Сохранить» работают не со ссылкой, а с файлом. Со ссылкой
/// системная шторка считает генерацию веб-страницей: показывает домен
/// `devsupplyr.shop`, тянет превью по сети (отсюда задержка в несколько секунд)
/// и предлагает «Копировать» и «Список для чтения» вместо «Сохранить видео».
///
/// Фотоплёнке файл тоже нужен именно файлом: видео-ресурс, добавленный данными,
/// Photos отвергает — из-за этого «Save» на ролике отвечал ошибкой.
///
/// Кладём в `Caches`: это копия того, что лежит на сервере, и потерять её
/// не жалко. Один и тот же файл второй раз не качаем.
actor GenerationFileStore {
    static let shared = GenerationFileStore()

    private let session: URLSession
    private var inFlight: [URL: Task<URL, Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func file(for item: LibraryItem) async throws -> URL {
        guard let remote = item.url else { throw CocoaError(.fileNoSuchFile) }
        if let running = inFlight[remote] {
            return try await running.value
        }

        let task = Task<URL, Error> { [session] in
            let destination = Self.destination(for: item, remote: remote)
            if FileManager.default.fileExists(atPath: destination.path) {
                return destination
            }

            let (temporary, _) = try await session.download(from: remote)
            try? FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporary, to: destination)
            return destination
        }
        inFlight[remote] = task

        defer { inFlight[remote] = nil }
        return try await task.value
    }

    /// Имя с расширением обязательно: и шторка, и Photos определяют тип файла
    /// по нему, а у ссылки генерации расширения нет вовсе.
    private nonisolated static func destination(for item: LibraryItem, remote: URL) -> URL {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let ext = item.kind == .video ? "mp4" : "png"
        let name = "generation-\(item.id).\(ext)"
        _ = remote
        return directory.appendingPathComponent("Generations").appendingPathComponent(name)
    }
}
