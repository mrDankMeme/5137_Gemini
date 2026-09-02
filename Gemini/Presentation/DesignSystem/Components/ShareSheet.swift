import SwiftUI
import UIKit

/// Системная шторка «Поделиться». В макете экраны `share` нарисованы именно ею,
/// поэтому своей вёрстки они не требуют.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

/// То, чем делятся. Обёртка нужна, чтобы показывать шторку через `sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
    /// Файл генерации, если он есть. С ним системная шторка сама предлагает
    /// «Save Image» и «Save Video» — это и есть сохранение в галерею, причём
    /// без запроса доступа к фотоплёнке.
    var url: URL?

    /// Чем делимся на самом деле: файлом, если он готов, иначе текстом.
    var activityItems: [Any] { url.map { [$0] } ?? [text] }
}
