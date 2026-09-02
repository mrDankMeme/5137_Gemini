import Foundation

/// Кеш, который чистит строка «Clear cache» в настройках.
///
/// Это ровно две вещи: кеш сетевых ответов `URLSession` и каталог `Library/Caches`,
/// куда система и мы складываем то, что не жалко потерять. Ни то ни другое не
/// является данными пользователя — библиотека генераций живёт на бэкенде, а
/// профиль Adapty в `Application Support`, которого мы не касаемся.
///
/// Считать и удалять уходим с главного потока: обход каталога — дисковая работа,
/// а строка настроек не должна ради неё подмораживать экран.
enum ResponseCacheStorage {
    /// Сколько занято сейчас, в байтах.
    static func size() async -> Int64 {
        await Task.detached(priority: .utility) {
            let responses = Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
            return responses + directorySize(cachesDirectory)
        }.value
    }

    /// Чистит и возвращает новый размер — чтобы вызывающему не пришлось
    /// делать второй заход и гадать, успело ли удаление.
    @discardableResult
    static func clear() async -> Int64 {
        await Task.detached(priority: .utility) {
            URLCache.shared.removeAllCachedResponses()

            if let cachesDirectory {
                let manager = FileManager.default
                let entries = (try? manager.contentsOfDirectory(
                    at: cachesDirectory,
                    includingPropertiesForKeys: nil
                )) ?? []
                for entry in entries {
                    // Занятый системой файл удалить нельзя — это не ошибка
                    // сценария, просто он останется в размере до перезапуска.
                    try? manager.removeItem(at: entry)
                }
            }

            let responses = Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage)
            return responses + directorySize(cachesDirectory)
        }.value
    }

    // Обе вспомогательные части читают только файловую систему и вызываются
    // из `Task.detached`: без `nonisolated` они остаются на главном акторе,
    // и обращение к ним из фонового контекста в Swift 6 станет ошибкой.
    private nonisolated static var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    private nonisolated static func directorySize(_ directory: URL?) -> Int64 {
        guard let directory,
              let walker = FileManager.default.enumerator(
                  at: directory,
                  includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
              )
        else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in walker {
            let values = try? url.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
            )
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}
