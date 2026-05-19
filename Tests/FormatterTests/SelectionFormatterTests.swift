import AppKit
import XCTest
@testable import Formatter

@MainActor
final class SelectionFormatterTests: XCTestCase {
    func testDisabledFormatterDoesNotTouchClipboard() {
        let harness = makeHarness(isEnabled: false)

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .disabled)
        XCTAssertFalse(harness.didPaste())
    }

    func testMissingAccessibilityRequestsPermissionWithoutTouchingClipboard() {
        var requestedPermission = false
        let harness = makeHarness(
            isAccessibilityTrusted: false,
            requestAccessibilityPermission: { requestedPermission = true }
        )

        harness.formatter.formatSelection()

        XCTAssertTrue(requestedPermission)
        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .permissionMissing)
        XCTAssertFalse(harness.didPaste())
    }

    func testUnsupportedTargetIsSafeNoOp() {
        let harness = makeHarness(target: .unsupported(name: "Pages"))

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .unsupportedTarget)
        XCTAssertFalse(harness.didPaste())
    }

    func testNoSelectionRestoresClipboard() {
        let harness = makeHarness(selectedText: "   \n")

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .noSelection)
        XCTAssertFalse(harness.didPaste())
    }

    func testAmbiguousMarkdownWithUnavailableModelRestoresClipboard() {
        let harness = makeHarness(
            selectedText: "```swift\nlet x = 1",
            ollamaStatus: .unavailable
        )

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .modelUnavailable)
        XCTAssertFalse(harness.didPaste())
    }

    func testRejectedModelFallbackRestoresClipboard() {
        let harness = makeHarness(
            selectedText: "```swift\nlet x = 1",
            ollamaStatus: .available(models: ["tiny-test-model"]),
            modelFallback: { _, _, _ in nil }
        )

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .modelRejected)
        XCTAssertFalse(harness.didPaste())
    }

    func testPasteboardWriteFailureRestoresClipboard() {
        let harness = makeHarness(
            selectedText: "Here is **bold**.",
            writePasteboard: { _, _ in false }
        )

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .pasteboardWriteFailed)
        XCTAssertFalse(harness.didPaste())
    }

    func testPasteFailureRestoresClipboard() {
        let harness = makeHarness(
            selectedText: "Here is **bold**.",
            pasteSelection: { false }
        )

        harness.formatter.formatSelection()

        XCTAssertEqual(harness.pasteboard.string(forType: .string), "before")
        XCTAssertEqual(harness.diagnostics.events.first?.code, .pasteFailed)
        XCTAssertFalse(harness.didPaste())
    }

    private func makeHarness(
        isEnabled: Bool = true,
        isAccessibilityTrusted: Bool = true,
        requestAccessibilityPermission: @escaping () -> Void = {},
        target: TargetApp = .slack,
        selectedText: String = "Here is **bold**.",
        ollamaStatus: OllamaStatus = .unavailable,
        modelFallback: @escaping (String, TargetApp, OllamaStatus) -> PastePayload? = { _, _, _ in nil },
        writePasteboard: @escaping (PastePayload, NSPasteboard) -> Bool = { PasteboardService.write($0, to: $1) },
        pasteSelection: (() -> Bool)? = nil
    ) -> SelectionFormatterHarness {
        let defaultsName = "FormatterTests.SelectionFormatter.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defaults.removePersistentDomain(forName: defaultsName)

        let preferences = PreferencesStore(defaults: defaults)
        preferences.isEnabled = isEnabled
        let diagnostics = DiagnosticStore()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FormatterTests.selection.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)

        var didPaste = false
        let pasteAction: () -> Bool = pasteSelection ?? {
            didPaste = true
            return true
        }

        let environment = SelectionFormatterEnvironment(
            isAccessibilityTrusted: { isAccessibilityTrusted },
            requestAccessibilityPermission: requestAccessibilityPermission,
            currentTarget: { target },
            pasteboard: { pasteboard },
            copySelection: {
                pasteboard.clearContents()
                pasteboard.setString(selectedText, forType: .string)
            },
            formatMarkdown: { MarkdownFormatter.format($0, for: $1) },
            modelFallback: modelFallback,
            writePasteboard: writePasteboard,
            pasteSelection: pasteAction,
            clipboardRestoreDelay: 0
        )

        let formatter = SelectionFormatter(
            preferences: preferences,
            diagnostics: diagnostics,
            environment: environment,
            ollamaStatusProvider: { ollamaStatus },
            statusHandler: { _ in }
        )

        return SelectionFormatterHarness(
            formatter: formatter,
            pasteboard: pasteboard,
            diagnostics: diagnostics,
            didPaste: { didPaste }
        )
    }
}

private struct SelectionFormatterHarness {
    let formatter: SelectionFormatter
    let pasteboard: NSPasteboard
    let diagnostics: DiagnosticStore
    let didPaste: () -> Bool
}
