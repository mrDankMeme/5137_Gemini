import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Откуда берётся вложение. Один источник правды вместо трёх булевых флагов:
/// два пикера одновременно всё равно не открыть.
enum AttachmentSource: Identifiable {
    case camera
    case photos
    case files

    var id: Self { self }
}

extension View {
    /// Вешает на экран все три пикера вложений.
    ///
    /// Пикер открывается **после** закрытия шторки выбора, а не из неё: UIKit
    /// отказывается презентовать с контроллера, который сам уже презентует, —
    /// та же грабля, что с окнами поверх меню.
    func attachmentPickers(
        source: Binding<AttachmentSource?>,
        onPicked: @escaping ([ChatAttachment]) -> Void,
        onFailure: @escaping (String) -> Void
    ) -> some View {
        modifier(AttachmentPickers(source: source, onPicked: onPicked, onFailure: onFailure))
    }
}

private struct AttachmentPickers: ViewModifier {
    @Binding var source: AttachmentSource?
    let onPicked: ([ChatAttachment]) -> Void
    let onFailure: (String) -> Void

    /// Столько вложений уходит в одно сообщение. Ограничение клиентское: до
    /// спецификации backend неизвестно, сколько он примет, а безлимитный выбор
    /// упрётся в размер запроса уже на реальной сети.
    private static let selectionLimit = 6

    @State private var photoSelection: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: binding(for: .photos),
                selection: $photoSelection,
                maxSelectionCount: Self.selectionLimit,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: photoSelection) { _, items in
                guard !items.isEmpty else { return }
                load(items)
            }
            .fileImporter(
                isPresented: binding(for: .files),
                allowedContentTypes: [.item],
                allowsMultipleSelection: true,
                onCompletion: handleFiles
            )
            .fullScreenCover(isPresented: binding(for: .camera)) {
                CameraPicker { attachment in
                    source = nil
                    if let attachment { onPicked([attachment]) }
                }
                .ignoresSafeArea()
            }
    }

    /// `Binding<Bool>` под конкретный источник: у каждого пикера свой флаг,
    /// а состояние одно.
    private func binding(for kind: AttachmentSource) -> Binding<Bool> {
        Binding(
            get: { source == kind },
            set: { if !$0, source == kind { source = nil } }
        )
    }

    private func load(_ items: [PhotosPickerItem]) {
        Task {
            var picked: [ChatAttachment] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                // Пикер отдаёт HEIC, а бэкенд принимает только jpeg/png/gif/webp
                // и молча отвергает остальное. Переводим в JPEG тем же рецептом,
                // что в 232, — заодно ужимаем: исходник с камеры весит десятки
                // мегабайт, а base64 добавляет ещё треть.
                let prepared = UIImage(data: data)?.preparedForUpload()
                picked.append(
                    ChatAttachment(
                        id: UUID().uuidString,
                        kind: .image,
                        payload: prepared ?? data,
                        mimeType: prepared == nil
                            ? (item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg")
                            : "image/jpeg"
                    )
                )
            }

            photoSelection = []
            source = nil
            // Молча проглотить неудачу нельзя: пользователь выбрал файлы и вправе
            // знать, что до сообщения они не дошли.
            if picked.isEmpty {
                onFailure(String(localized: "Couldn’t read the selected files."))
            } else {
                onPicked(picked)
            }
        }
    }

    private func handleFiles(_ result: Result<[URL], Error>) {
        source = nil
        guard case let .success(urls) = result else {
            onFailure(String(localized: "Couldn’t open the selected files."))
            return
        }

        var picked: [ChatAttachment] = []
        var rejected: [String] = []
        for url in urls.prefix(Self.selectionLimit) {
            // Файл из чужого контейнера читается только внутри этой пары вызовов.
            let isReachable = url.startAccessingSecurityScopedResource()
            defer { if isReachable { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else { continue }

            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                ?? "application/octet-stream"
            // Отказываем здесь, а не на отправке: иначе файл проходит пикер,
            // показывается чипом и молча пропадает, а модель отвечает так,
            // будто ничего не прикладывали.
            guard AttachmentFormatSupport.isSupported(mimeType: mime, data: data) else {
                rejected.append(url.lastPathComponent)
                continue
            }

            picked.append(
                ChatAttachment(
                    id: UUID().uuidString,
                    kind: .document(name: url.lastPathComponent),
                    payload: data,
                    mimeType: mime
                )
            )
        }

        if !rejected.isEmpty {
            onFailure(String(
                localized: "This file type isn’t supported: \(rejected.joined(separator: ", "))"
            ))
        }

        if picked.isEmpty {
            if rejected.isEmpty {
                onFailure(String(localized: "Couldn’t read the selected files."))
            }
        } else {
            onPicked(picked)
        }
    }
}

/// Съёмка с камеры. `UIImagePickerController`, потому что SwiftUI своей камеры
/// не даёт — только выбор из готовых медиа.
private struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (ChatAttachment?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        // На симуляторе камеры нет — там открывается фотоплёнка, и экран
        // не остаётся пустым.
        controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onFinish: (ChatAttachment?) -> Void

        init(onFinish: @escaping (ChatAttachment?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9)
            else {
                onFinish(nil)
                return
            }
            onFinish(
                ChatAttachment(
                    id: UUID().uuidString,
                    kind: .image,
                    payload: data,
                    mimeType: "image/jpeg"
                )
            )
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
