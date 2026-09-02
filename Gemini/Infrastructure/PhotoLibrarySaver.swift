import Foundation
import Photos

/// Сохранение готовой генерации в фотоплёнку.
///
/// «Save» на просмотре генерации — это именно фотоплёнка, а не «сохранить
/// на сервере»: на сервере генерация лежит с момента создания, отдельной
/// ручки у backend нет, и раньше кнопка не делала ровно ничего — ни файла,
/// ни запроса прав, ни сообщения.
///
/// Права спрашиваются в режиме `addOnly`: приложению нужно только положить
/// свой файл, читать чужие фотографии для этого незачем.
struct PhotoLibrarySaver: Sendable {
    enum Failure: Error {
        /// Пользователь запретил доступ или его ограничили родительским контролем.
        case notAuthorized
        /// Файл не скачался — сеть или просроченная ссылка.
        case unavailable
    }

    func save(_ item: LibraryItem) async throws {
        guard item.url != nil else { throw Failure.unavailable }
        guard await authorize() else { throw Failure.notAuthorized }

        let file: URL
        do {
            file = try await GenerationFileStore.shared.file(for: item)
        } catch {
            throw Failure.unavailable
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            // Файлом, а не данными: видео-ресурс, добавленный данными, Photos
            // отвергает — из-за этого «Save» на ролике отвечал ошибкой.
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(
                with: item.kind == .video ? .video : .photo,
                fileURL: file,
                options: options
            )
        }
    }

    private func authorize() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        default:
            return false
        }
    }
}
