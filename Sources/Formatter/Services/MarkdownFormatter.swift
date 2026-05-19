import AppKit
import Foundation

struct FormatResult: Equatable {
    var payload: PastePayload
    var isAmbiguous: Bool
}

enum MarkdownFormatter {
    static func format(_ markdown: String, for target: TargetApp) -> FormatResult {
        if target.prefersMarkdownPlainText {
            return FormatResult(
                payload: PastePayload(plainText: markdown, html: nil, rtfData: nil),
                isAmbiguous: false
            )
        }

        let usesSlackHTML = {
            if case .slack = target { return true }
            return false
        }()
        let htmlFragment = renderHTMLFragment(markdown, flattenOrderedLists: usesSlackHTML)
        let htmlDocument = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; font-size: 14px; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: rgba(127,127,127,0.12); padding: 1px 3px; border-radius: 3px; }
        pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; white-space: pre-wrap; background: rgba(127,127,127,0.10); padding: 8px; border-radius: 6px; }
        blockquote { border-left: 3px solid #d0d0d0; margin: 0 0 8px 0; padding-left: 12px; color: #555; }
        </style>
        </head>
        <body>\(htmlFragment)</body>
        </html>
        """

        let rtfData: Data?
        if case .slack = target {
            rtfData = nil
        } else {
            rtfData = makeRTF(fromHTML: htmlDocument)
        }

        return FormatResult(
            payload: PastePayload(
                plainText: renderPlainText(markdown),
                html: htmlDocument,
                rtfData: rtfData
            ),
            isAmbiguous: MarkdownAnalysis.hasAmbiguousStructure(markdown)
        )
    }

    static func renderHTMLFragment(_ markdown: String, flattenOrderedLists: Bool = false) -> String {
        var parts: [String] = []
        var inUnorderedList = false
        var inOrderedList = false
        var inCodeBlock = false
        var codeBlockLines: [String] = []

        func closeLists() {
            if inUnorderedList {
                parts.append("</ul>")
                inUnorderedList = false
            }
            if inOrderedList {
                parts.append("</ol>")
                inOrderedList = false
            }
        }

        func flushCodeBlock() {
            guard !codeBlockLines.isEmpty else { return }
            parts.append("<pre><code>\(escapeHTML(codeBlockLines.joined(separator: "\n")))</code></pre>")
            codeBlockLines.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                closeLists()
                if inCodeBlock {
                    flushCodeBlock()
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                closeLists()
                parts.append("<p><br></p>")
                continue
            }

            if let heading = headingText(from: trimmed) {
                closeLists()
                parts.append("<h1>\(renderInlineHTML(heading))</h1>")
                continue
            }

            if let bullet = unorderedListText(from: line) {
                if inOrderedList {
                    parts.append("</ol>")
                    inOrderedList = false
                }
                if !inUnorderedList {
                    parts.append("<ul>")
                    inUnorderedList = true
                }
                let indent = leadingSpaceCount(line) >= 2 ? " style=\"margin-left: 18px;\"" : ""
                parts.append("<li\(indent)>\(renderInlineHTML(bullet))</li>")
                continue
            }

            if let item = orderedListText(from: trimmed) {
                if flattenOrderedLists {
                    closeLists()
                    let number = trimmed.prefix { $0.isNumber }
                    parts.append("<p>\(number). \(renderInlineHTML(item))</p>")
                    continue
                }

                if inUnorderedList {
                    parts.append("</ul>")
                    inUnorderedList = false
                }
                if !inOrderedList {
                    parts.append("<ol>")
                    inOrderedList = true
                }
                parts.append("<li>\(renderInlineHTML(item))</li>")
                continue
            }

            if let quote = blockquoteText(from: trimmed) {
                closeLists()
                parts.append("<blockquote>\(renderInlineHTML(quote))</blockquote>")
                continue
            }

            closeLists()
            parts.append("<p>\(renderInlineHTML(line))</p>")
        }

        closeLists()
        if inCodeBlock {
            flushCodeBlock()
        }

        return parts.joined(separator: "\n")
    }

    static func renderPlainText(_ markdown: String) -> String {
        var output: [String] = []
        var inCodeBlock = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                output.append(rawLine)
                continue
            }

            if trimmed.isEmpty {
                output.append("")
            } else if let heading = headingText(from: trimmed) {
                output.append(stripInlineMarkdown(heading))
            } else if let bullet = unorderedListText(from: rawLine) {
                let prefix = leadingSpaceCount(rawLine) >= 2 ? "  - " : "- "
                output.append(prefix + stripInlineMarkdown(bullet))
            } else if let item = orderedListText(from: trimmed) {
                let number = trimmed.prefix { $0.isNumber }
                output.append("\(number). \(stripInlineMarkdown(item))")
            } else if let quote = blockquoteText(from: trimmed) {
                output.append("> \(stripInlineMarkdown(quote))")
            } else {
                output.append(stripInlineMarkdown(rawLine))
            }
        }

        return output.joined(separator: "\n")
    }

    static func renderInlineHTML(_ text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("**"),
               let end = text[index...].dropFirst(2).range(of: "**")?.lowerBound {
                let innerStart = text.index(index, offsetBy: 2)
                result += "<strong>\(escapeHTML(String(text[innerStart..<end])))</strong>"
                index = text.index(end, offsetBy: 2)
                continue
            }

            if text[index] == "*",
               let end = text[text.index(after: index)...].firstIndex(of: "*") {
                let innerStart = text.index(after: index)
                result += "<em>\(escapeHTML(String(text[innerStart..<end])))</em>"
                index = text.index(after: end)
                continue
            }

            if text[index] == "`",
               let end = text[text.index(after: index)...].firstIndex(of: "`") {
                let innerStart = text.index(after: index)
                result += "<code>\(escapeHTML(String(text[innerStart..<end])))</code>"
                index = text.index(after: end)
                continue
            }

            result += escapeHTML(String(text[index]))
            index = text.index(after: index)
        }

        return result
    }

    static func stripInlineMarkdown(_ text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("**"),
               let end = text[index...].dropFirst(2).range(of: "**")?.lowerBound {
                let innerStart = text.index(index, offsetBy: 2)
                result += String(text[innerStart..<end])
                index = text.index(end, offsetBy: 2)
                continue
            }

            if text[index] == "*",
               let end = text[text.index(after: index)...].firstIndex(of: "*") {
                let innerStart = text.index(after: index)
                result += String(text[innerStart..<end])
                index = text.index(after: end)
                continue
            }

            if text[index] == "`",
               let end = text[text.index(after: index)...].firstIndex(of: "`") {
                let innerStart = text.index(after: index)
                result += String(text[innerStart..<end])
                index = text.index(after: end)
                continue
            }

            result.append(text[index])
            index = text.index(after: index)
        }

        return result
    }

    static func makeRTF(fromHTML html: String) -> Data? {
        guard let data = html.data(using: .utf8) else { return nil }
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else {
            return nil
        }

        let range = NSRange(location: 0, length: attributed.length)
        return try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func headingText(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("# ") else { return nil }
        return String(trimmedLine.dropFirst(2))
    }

    private static func unorderedListText(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") else { return nil }
        return String(trimmed.dropFirst(2))
    }

    private static func orderedListText(from trimmedLine: String) -> String? {
        guard let dot = trimmedLine.firstIndex(of: ".") else { return nil }
        let number = trimmedLine[..<dot]
        guard !number.isEmpty, number.allSatisfy({ $0.isNumber }) else { return nil }
        let afterDot = trimmedLine.index(after: dot)
        guard afterDot < trimmedLine.endIndex, trimmedLine[afterDot] == " " else { return nil }
        return String(trimmedLine[trimmedLine.index(after: afterDot)...])
    }

    private static func blockquoteText(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("> ") else { return nil }
        return String(trimmedLine.dropFirst(2))
    }

    private static func leadingSpaceCount(_ line: String) -> Int {
        line.prefix { $0 == " " }.count
    }
}

enum MarkdownAnalysis {
    static func hasAmbiguousStructure(_ markdown: String) -> Bool {
        countOccurrences(of: "```", in: markdown) % 2 != 0
            || countOccurrences(of: "**", in: markdown) % 2 != 0
            || countOccurrences(of: "`", in: markdown) % 2 != 0
    }

    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }
}
