import SwiftUI

/// Знак приложения: искра на светло-синем скруглённом квадрате.
///
/// Используется на splash, в попапе обновления и в ин-апп баннере, поэтому
/// вынесен отдельно и масштабируется по переданному размеру.
struct AppMark: View {
    var size: CGFloat = 140

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.229, style: .continuous)
            .fill(Color(.sRGB, red: 0.855, green: 0.910, blue: 1.0))
            .frame(width: size, height: size)
            .overlay {
                SparkleShape()
                    .fill(AppColor.accent)
                    .frame(width: size * 0.593, height: size * 0.593)
            }
            .accessibilityHidden(true)
    }
}
