import XCTest
@testable import Formatter

final class MarkdownFormatterTests: XCTestCase {
    private let sample = """
    # Format Hotkey Test

    Here is **bold text**, *italic text*, and `inline code`.

    - First bullet
    - Second bullet with **bold**
      - Nested bullet

    1. First numbered item
    2. Second numbered item

    > Quoted line stays quoted.

    Plain paragraph after the quote.
    """

    func testSlackTargetGetsHTMLWithoutRTF() {
        let result = MarkdownFormatter.format(sample, for: .slack)

        XCTAssertFalse(result.isAmbiguous)
        XCTAssertTrue(result.payload.html?.contains("<strong>bold text</strong>") == true)
        XCTAssertTrue(result.payload.html?.contains("<em>italic text</em>") == true)
        XCTAssertTrue(result.payload.html?.contains("<li>First bullet</li>") == true)
        XCTAssertTrue(result.payload.html?.contains("<p>2. Second numbered item</p>") == true)
        XCTAssertFalse(result.payload.html?.contains("<ol>") == true)
        XCTAssertTrue(result.payload.html?.contains("<blockquote>Quoted line stays quoted.</blockquote>") == true)
        XCTAssertNil(result.payload.rtfData)
    }

    func testRichNonSlackTargetsGetHTMLAndRTF() {
        let result = MarkdownFormatter.format(sample, for: .superhuman)

        XCTAssertFalse(result.isAmbiguous)
        XCTAssertTrue(result.payload.html?.contains("<strong>bold text</strong>") == true)
        XCTAssertNotNil(result.payload.rtfData)
    }

    func testUnicodeBulletGlyphsBecomeRichListItems() {
        let markdown = """
        What I'm thinking about:

        • Who maintains the mapping?

        • How is it measured?

        • What evidence proves it?
        """

        let result = MarkdownFormatter.format(markdown, for: .superhuman)

        XCTAssertTrue(result.payload.html?.contains("<li>Who maintains the mapping?</li>") == true)
        XCTAssertTrue(result.payload.html?.contains("<li>How is it measured?</li>") == true)
        XCTAssertTrue(result.payload.html?.contains("<li>What evidence proves it?</li>") == true)
        XCTAssertEqual(
            result.payload.plainText,
            """
            What I'm thinking about:

            - Who maintains the mapping?

            - How is it measured?

            - What evidence proves it?
            """
        )
    }

    func testPlainTextPreservesWordsWithoutMarkdownMarkers() {
        let plain = MarkdownFormatter.renderPlainText(sample)

        XCTAssertTrue(plain.contains("Format Hotkey Test"))
        XCTAssertTrue(plain.contains("Here is bold text, italic text, and inline code."))
        XCTAssertTrue(plain.contains("- Second bullet with bold"))
        XCTAssertTrue(plain.contains("> Quoted line stays quoted."))
        XCTAssertFalse(plain.contains("**bold text**"))
        XCTAssertFalse(plain.contains("*italic text*"))
        XCTAssertFalse(plain.contains("`inline code`"))
    }

    func testChatGPTKeepsMarkdownAsPlainText() {
        let result = MarkdownFormatter.format(sample, for: .chatGPT)

        XCTAssertEqual(result.payload.plainText, sample)
        XCTAssertNil(result.payload.html)
        XCTAssertNil(result.payload.rtfData)
    }

    func testAmbiguousFenceIsDetected() {
        XCTAssertTrue(MarkdownAnalysis.hasAmbiguousStructure("```swift\nlet x = 1"))
    }
}
