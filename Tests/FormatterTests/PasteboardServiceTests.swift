import AppKit
import XCTest
@testable import Formatter

final class PasteboardServiceTests: XCTestCase {
    func testPayloadWritesPlainHTMLAndRTFTypes() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FormatterTests.payload"))
        let payload = MarkdownFormatter.format("Here is **bold**.", for: .superhuman).payload

        XCTAssertTrue(PasteboardService.write(payload, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "Here is bold.")
        XCTAssertNotNil(pasteboard.string(forType: .html))
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
    }

    func testSnapshotRestoresClipboardTypes() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FormatterTests.snapshot"))
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("after", forType: .string)

        snapshot.restore(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "before")
    }
}
