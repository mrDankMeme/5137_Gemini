import Foundation

/// Параметры генерации, которые пользователь выбирает перед запуском.
///
/// Состав зависит от модели: у изображений — пропорции и разрешение,
/// у видео добавляются звук и длительность.
/// `nonisolated` по той же причине, что и остальные сущности переписки:
/// настройки читает сетевой репозиторий, а это актор вне главного.
nonisolated struct GenerationSettings: Equatable {
    /// Пропорции кадра. Порядок — как в макете.
    ///
    /// `rawValue` уходит на сервер, `title` показывается пользователю. Раньше
    /// это было одно и то же, и на ручку ушли бы подписи вроде «5 sec» и «Auto».
    enum AspectRatio: String, CaseIterable, Identifiable {
        case square = "1:1"
        case portrait2x3 = "2:3"
        case portrait3x4 = "3:4"
        case landscape4x3 = "4:3"
        case landscape16x9 = "16:9"
        case portrait9x16 = "9:16"
        case portrait9x21 = "9:21"
        case landscape21x9 = "21:9"
        case auto = "Auto"

        var id: String { rawValue }

        /// «Auto» — единственная подпись-слово среди пропорций, остальные
        /// (`1:1`, `16:9`) одинаковы на всех языках.
        var title: String { self == .auto ? String(localized: "Auto") : rawValue }

        /// Что уходит на сервер. У «Auto» параметра нет вовсе — поле опускается,
        /// а не отправляется строкой.
        var wireValue: String? { self == .auto ? nil : rawValue }

        /// Соотношение сторон для иконки-превью. У `Auto` иконки нет.
        var previewRatio: Double? {
            guard self != .auto else { return nil }
            let parts = rawValue.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 2, parts[1] != 0 else { return nil }
            return parts[0] / parts[1]
        }
    }

    enum Resolution: String, CaseIterable, Identifiable {
        case oneK = "1k"
        case twoK = "2k"
        case fourK = "4k"

        var id: String { rawValue }
        var title: String { rawValue }
        /// На сервер уходит заглавная «K» — ровно в таком виде ступени названы
        /// в каталоге медиа-моделей (`resolutionCredits`), и по ним же считается цена.
        var wireValue: String { rawValue.uppercased() }

        /// Как эта же ступень может называться у видео-моделей. Словарь у них
        /// свой: Veo принимает «720p»/«1080p»/«4k», и на «1K» отвечает
        /// `422 resolution is not supported by this model in this mode`.
        var wireCandidates: [String] {
            switch self {
            case .oneK: [wireValue, "720p"]
            case .twoK: [wireValue, "1080p"]
            case .fourK: [wireValue, "2160p"]
            }
        }

        /// Что отправить модели с такими ступенями. `nil` — модель ступеней
        /// не принимает (так у Kling), и поле надо опустить целиком.
        func wireValue(supportedBy supported: [String]) -> String? {
            guard !supported.isEmpty else { return nil }
            for candidate in wireCandidates {
                if let match = supported.first(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
                    return match
                }
            }
            return nil
        }
    }

    enum Duration: Int, CaseIterable, Identifiable {
        case five = 5
        case ten = 10
        case fifteen = 15

        var id: Int { rawValue }
        /// Подпись из макета. Сокращение единицы времени переводится: «сек».
        var title: String { String(localized: "\(rawValue) sec") }
        /// На сервер уходит число секунд, а не подпись.
        var wireValue: Int { rawValue }
    }

    var aspectRatio: AspectRatio = .portrait9x16
    var resolution: Resolution = .fourK
    var isSoundOn = true
    var duration: Duration = .five
}
