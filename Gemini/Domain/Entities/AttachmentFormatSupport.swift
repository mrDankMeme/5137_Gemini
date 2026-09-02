import Foundation

/// Какие файлы вообще можно приложить.
///
/// Правило домена, а не экрана: пикер по нему отказывает сразу, а сетевой слой
/// по нему же раскладывает вложение по категориям бэкенда. Одна проверка на
/// оба места — иначе файл проходит пикер, показывается чипом и молча пропадает
/// на отправке, а модель отвечает так, будто ничего не прикладывали.
enum AttachmentFormatSupport {
    static func isSupported(mimeType: String, data: Data) -> Bool {
        let mime = mimeType.lowercased()
        if mime.hasPrefix("image/") {
            return true
        }
        if mime == "application/pdf" || data.starts(with: Data("%PDF".utf8)) {
            return true
        }
        return isValidUTF8(data)
    }

    /// Намеренно не `String(data:encoding:)`: тот строит вторую копию файла
    /// целиком, чтобы её тут же выбросить. Пикер пускает большие файлы, а следом
    /// идёт base64 — на этой копии крупное вложение и роняло бы приложение
    /// по памяти. Разбор байтов отвечает на тот же вопрос и не выделяет ничего.
    nonisolated static func isValidUTF8(_ data: Data) -> Bool {
        var iterator = data.makeIterator()
        var parser = UTF8.ForwardParser()
        while true {
            switch parser.parseScalar(from: &iterator) {
            case .valid: continue
            case .emptyInput: return true
            case .error: return false
            }
        }
    }
}
