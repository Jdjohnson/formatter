import Foundation

enum LocalModelFallback {
    static func format(_ markdown: String, target: TargetApp, ollamaStatus: OllamaStatus) -> PastePayload? {
        guard let model = ollamaStatus.preferredModel else { return nil }
        let expectedPlain = MarkdownFormatter.renderPlainText(markdown)
        let prompt = """
        You are a local formatting converter. Preserve the user's text content exactly.
        Convert this Markdown into an HTML fragment suitable for \(target.displayName).
        Return only HTML, with no commentary. Do not add, remove, summarize, or rewrite words.

        Markdown:
        \(markdown)
        """

        guard let htmlFragment = OllamaClient.default.runModel(model: model, prompt: prompt) else {
            return nil
        }

        let html = "<!doctype html><html><body>\(htmlFragment)</body></html>"
        let extractedPlain = HTMLPlainTextExtractor.extract(html)
        guard normalize(extractedPlain) == normalize(expectedPlain) else {
            return nil
        }

        return PastePayload(
            plainText: expectedPlain,
            html: html,
            rtfData: MarkdownFormatter.makeRTF(fromHTML: html)
        )
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum HTMLPlainTextExtractor {
    static func extract(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
