import XCTest
@testable import Formatter

@MainActor
final class DiagnosticStoreTests: XCTestCase {
    func testDiagnosticsDoNotStoreSelectedText() {
        let store = DiagnosticStore()
        let selectedText = "Private selected text that must never be logged"

        store.record(.parserUncertain, target: .slack)

        XCTAssertFalse(store.containsSelectedText(selectedText))
        XCTAssertFalse(store.events.map(\.message).joined(separator: " ").contains(selectedText))
    }
}
