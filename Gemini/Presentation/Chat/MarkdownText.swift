import SwiftUI
import UIKit

/// Ответ ассистента с блочным markdown: абзацы, заголовки, списки, разделители
/// и листинги кода.
///
/// `AttributedString(markdown:)` разбирает только **строчную** разметку внутри одного
/// блока — жирный, курсив, ссылки, — но ничего не знает про списки, заголовки и
/// горизонтальные линии. Поэтому текст сначала режется на блоки вручную,
/// а внутри каждого блока работает уже системный парсер.
///
/// Текст ответа **выделяется**: `.textSelection(.enabled)` стоит на каждом блоке.
/// Выделить разом весь ответ нельзя — SwiftUI не умеет тянуть выделение через
/// границу `Text`; для «скопировать целиком» под ответом есть кнопка Copy.
struct MarkdownText: View {
    /// Блоки считаются один раз при создании вью. Раньше `parse` вызывался прямо
    /// в `body` и повторялся на каждую перерисовку — а при потоковом ответе это
    /// был бы полный разбор текста на каждый пришедший кусок.
    private let blocks: [Block]

    init(text: String) {
        blocks = Self.parse(text)
    }

    private enum Block: Equatable {
        case paragraph(String)
        case heading(String)
        case bullet([String])
        /// Номер берётся из разметки, а не из позиции в блоке: между пунктами
        /// бывает абзац, он разрывает список, и нумерация по позиции начинала
        /// бы каждый кусок заново — «1.», «1.», «1.» вместо 1, 2, 3.
        case numbered([NumberedItem])
        case divider
        /// Листинг между ```` ``` ````. Язык из строки открытия — если он указан.
        case code(language: String?, content: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                view(for: block)
                    .padding(.top, topSpacing(at: index))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Ответ можно выделять и копировать кусками — по умолчанию `Text` в SwiftUI
        // не выделяется вообще.
        .textSelection(.enabled)
    }

    /// Шаг сверху у блока. Первый блок без отступа, после заголовка — короткий,
    /// между разделами — полный: так лента набрана в макете.
    private func topSpacing(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        if case .heading = blocks[index - 1] {
            return AppMetrics.answerHeadingGap
        }
        return AppMetrics.answerBlockGap
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case let .paragraph(content):
            inline(content)
                .appTextStyle(AppFont.reply)
                .foregroundStyle(AppColor.textPrimary)

        case let .heading(content):
            inline(content)
                .appTextStyle(AppFont.h4)
                .foregroundStyle(AppColor.textPrimary)

        case let .bullet(items):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    marker(Text(verbatim: "•"), content: item)
                }
            }

        case let .numbered(items):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    marker(Text(verbatim: "\(item.number)."), content: item.text)
                }
            }

        case .divider:
            Rectangle()
                .fill(AppColor.strokePrimary)
                .frame(height: AppMetrics.hairline)

        case let .code(language, content):
            CodeBlock(language: language, content: content)
        }
    }

    private func marker(_ bullet: Text, content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            bullet
                .appTextStyle(AppFont.reply)
                .foregroundStyle(AppColor.textSecondary)
            inline(content)
                .appTextStyle(AppFont.reply)
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Строчная разметка внутри блока. Если markdown невалидный — показываем как есть,
    /// а не роняем экран и не теряем текст.
    private func inline(_ content: String) -> Text {
        guard var attributed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return Text(content)
        }

        // Строчный `code` парсер размечает намерением, но шрифт не подставляет:
        // без этого `foo()` в тексте ничем не отличается от обычного слова.
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].font = AppFont.Icon.inlineCode
            attributed[run.range].foregroundColor = AppColor.textMuted
        }
        return Text(attributed)
    }

    // MARK: Разбор на блоки

    private static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbers: [NumberedItem] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
        func flushLists() {
            if !bullets.isEmpty { blocks.append(.bullet(bullets)); bullets.removeAll() }
            if !numbers.isEmpty { blocks.append(.numbered(numbers)); numbers.removeAll() }
        }
        func flushAll() {
            flushParagraph()
            flushLists()
        }

        var codeLines: [String] = []
        var codeLanguage: String?
        var isInsideCode = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Забор листинга. Внутри него строки не разбираются вообще:
            // `# comment` и `- item` в коде — это код, а не заголовок со списком.
            if line.hasPrefix("```") {
                if isInsideCode {
                    blocks.append(.code(language: codeLanguage,
                                        content: codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    codeLanguage = nil
                    isInsideCode = false
                } else {
                    flushAll()
                    let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = language.isEmpty ? nil : language
                    isInsideCode = true
                }
                continue
            }
            if isInsideCode {
                // Именно `rawLine`: в листинге отступы значимы.
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushAll()
                continue
            }
            if line.allSatisfy({ $0 == "-" }), line.count >= 3 {
                flushAll()
                blocks.append(.divider)
                continue
            }
            if let heading = headingContent(of: line) {
                flushAll()
                blocks.append(.heading(heading))
                continue
            }
            if let item = bulletContent(of: line) {
                flushParagraph()
                if !numbers.isEmpty { flushLists() }
                bullets.append(item)
                continue
            }
            if let item = numberedContent(of: line) {
                flushParagraph()
                if !bullets.isEmpty { flushLists() }
                numbers.append(item)
                continue
            }

            flushLists()
            paragraph.append(line)
        }

        // Ответ мог оборваться на середине листинга — потоковая выдача и обрыв сети
        // это норма. Текст показываем, а не теряем.
        if isInsideCode, !codeLines.isEmpty {
            blocks.append(.code(language: codeLanguage, content: codeLines.joined(separator: "\n")))
        }
        flushAll()
        return blocks
    }

    private static func headingContent(of line: String) -> String? {
        if line.hasPrefix("#") {
            let content = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return content.isEmpty ? nil : content
        }
        // Строка целиком в `**жирном**` — в макете так набраны подзаголовки ответа.
        if line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 {
            return String(line.dropFirst(2).dropLast(2))
        }
        return nil
    }

    private static func bulletContent(of line: String) -> String? {
        for prefix in ["- ", "* ", "• "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
        return nil
    }

    private static func numberedContent(of line: String) -> NumberedItem? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return NumberedItem(number: number, text: String(rest.dropFirst(2)))
    }
}

/// Пункт нумерованного списка вместе с его номером из разметки.
struct NumberedItem: Equatable {
    let number: Int
    let text: String
}

/// Листинг кода: шапка с языком и копированием, моноширинный текст с горизонтальным
/// скроллом.
///
/// Скролл именно у листинга, а не у всей переписки: длинная строка кода не должна
/// растягивать ленту сообщений по ширине.
private struct CodeBlock: View {
    let language: String?
    let content: String

    @State private var isCopied = false
    @Environment(\.showToast) private var showToast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(.horizontal) {
                Text(content)
                    .appTextStyle(AppFont.code)
                    .foregroundStyle(AppColor.textPrimary)
                    .textSelection(.enabled)
                    .padding(Spacing.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColor.bgSecondary, in: .rect(cornerRadius: AppMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                .strokeBorder(AppColor.strokeSecondary, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Text(language ?? "code")
                .appTextStyle(AppFont.codeCaption)
                .foregroundStyle(AppColor.textTertiary)

            Spacer(minLength: 8)

            Button(action: copy) {
                Label(
                    isCopied ? "Copied" : "Copy",
                    systemImage: isCopied ? "checkmark" : "doc.on.doc"
                )
                .appTextStyle(AppFont.codeCaption)
                .foregroundStyle(AppColor.textSecondary)
                .frame(minWidth: AppMetrics.tapTarget, minHeight: AppMetrics.tapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy code")
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xs)
        .frame(minHeight: AppMetrics.tapTarget)
        .background(AppColor.bgElevatedStrong)
    }

    private func copy() {
        UIPasteboard.general.string = content
        showToast(.copied(String(localized: "Code copied")))
        // Подтверждение вместо тишины: без него непонятно, сработала кнопка или нет.
        withAnimation(.easeOut(duration: 0.15)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.15)) { isCopied = false }
        }
    }
}

#Preview {
    ScrollView {
        MarkdownText(text: """
        A quick, healthy breakfast idea that is simple, balanced, and truly satisfying:

        ---

        **🥣 What It Looks Like In Practice**

        - Greek yogurt — 150–200 g, preferably unsweetened
        - Fresh berries — blueberries, raspberries, strawberries
        - Nuts or seeds — almonds, walnuts, chia, or pumpkin seeds

        **⭐ Why It Works**

        1. High protein → satisfying
        2. Healthy fats → provide lasting energy

        Call `prepare(bowl:)` before serving:

        ```swift
        func prepare(bowl: Bowl) {
            bowl.add(.yogurt, grams: 180)
            bowl.add(.berries)
        }
        ```
        """)
        .padding(AppMetrics.screenPadding)
    }
    .background(AppColor.bgPrimary)
}
