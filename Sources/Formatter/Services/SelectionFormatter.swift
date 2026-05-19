import AppKit

struct SelectionFormatterEnvironment {
    var isAccessibilityTrusted: () -> Bool
    var requestAccessibilityPermission: () -> Void
    var currentTarget: () -> TargetApp
    var pasteboard: () -> NSPasteboard
    var copySelection: () -> Void
    var formatMarkdown: (String, TargetApp) -> FormatResult
    var modelFallback: (String, TargetApp, OllamaStatus) -> PastePayload?
    var writePasteboard: (PastePayload, NSPasteboard) -> Bool
    var pasteSelection: () -> Bool
    var clipboardRestoreDelay: TimeInterval

    static let live = SelectionFormatterEnvironment(
        isAccessibilityTrusted: { PermissionService.isAccessibilityTrusted },
        requestAccessibilityPermission: { PermissionService.requestAccessibilityPermission() },
        currentTarget: { TargetDetector.current() },
        pasteboard: { NSPasteboard.general },
        copySelection: { KeyboardSimulator.copy() },
        formatMarkdown: { MarkdownFormatter.format($0, for: $1) },
        modelFallback: { LocalModelFallback.format($0, target: $1, ollamaStatus: $2) },
        writePasteboard: { PasteboardService.write($0, to: $1) },
        pasteSelection: { KeyboardSimulator.paste() },
        clipboardRestoreDelay: 4.0
    )
}

@MainActor
final class SelectionFormatter {
    private let preferences: PreferencesStore
    private let diagnostics: DiagnosticStore
    private let statusHandler: (FormatterStatus) -> Void
    private let environment: SelectionFormatterEnvironment
    private var ollamaStatusProvider: () -> OllamaStatus

    init(
        preferences: PreferencesStore,
        diagnostics: DiagnosticStore,
        environment: SelectionFormatterEnvironment = .live,
        ollamaStatusProvider: @escaping () -> OllamaStatus = { .unknown },
        statusHandler: @escaping (FormatterStatus) -> Void
    ) {
        self.preferences = preferences
        self.diagnostics = diagnostics
        self.environment = environment
        self.ollamaStatusProvider = ollamaStatusProvider
        self.statusHandler = statusHandler
    }

    func formatSelection() {
        guard preferences.isEnabled else {
            FileEventLog.append("format_blocked_disabled")
            diagnostics.record(.disabled, target: nil)
            statusHandler(.failed("Formatter disabled"))
            return
        }

        guard environment.isAccessibilityTrusted() else {
            FileEventLog.append("format_blocked_accessibility")
            diagnostics.record(.permissionMissing, target: nil)
            statusHandler(.failed("Accessibility permission needed"))
            environment.requestAccessibilityPermission()
            return
        }

        let target = environment.currentTarget()
        FileEventLog.append("format_target_\(target.logIdentifier)")
        guard target.isSupported else {
            FileEventLog.append("format_blocked_unsupported")
            diagnostics.record(.unsupportedTarget, target: target)
            statusHandler(.failed("Unsupported app: \(target.displayName)"))
            return
        }

        statusHandler(.working)

        let pasteboard = environment.pasteboard()
        let previousPasteboard = PasteboardSnapshot.capture(from: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        environment.copySelection()
        let selectedText = waitForCopiedText(on: pasteboard, previousChangeCount: previousChangeCount)

        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            previousPasteboard.restore(to: pasteboard)
            FileEventLog.append("format_blocked_no_selection")
            diagnostics.record(.noSelection, target: target)
            statusHandler(.failed("No selected text"))
            return
        }

        var result = environment.formatMarkdown(selectedText, target)
        if result.isAmbiguous {
            let ollamaStatus = ollamaStatusProvider()
            guard ollamaStatus.preferredModel != nil else {
                previousPasteboard.restore(to: pasteboard)
                FileEventLog.append("format_blocked_model_unavailable")
                diagnostics.record(.modelUnavailable, target: target)
                statusHandler(.failed("Local model unavailable"))
                return
            }

            if let fallback = environment.modelFallback(selectedText, target, ollamaStatus) {
                result = FormatResult(payload: fallback, isAmbiguous: false)
            } else {
                previousPasteboard.restore(to: pasteboard)
                FileEventLog.append("format_blocked_model_rejected")
                diagnostics.record(.modelRejected, target: target)
                statusHandler(.failed("Could not format safely"))
                return
            }
        }

        guard result.payload.hasUsefulOutput, environment.writePasteboard(result.payload, pasteboard) else {
            previousPasteboard.restore(to: pasteboard)
            FileEventLog.append("format_blocked_pasteboard_write")
            diagnostics.record(.pasteboardWriteFailed, target: target)
            statusHandler(.failed("Could not prepare paste"))
            return
        }

        guard environment.pasteSelection() else {
            previousPasteboard.restore(to: pasteboard)
            FileEventLog.append("format_blocked_paste_failed")
            diagnostics.record(.pasteFailed, target: target)
            statusHandler(.failed("Could not paste"))
            return
        }

        FileEventLog.append("format_paste_sent")
        diagnostics.record(.formatSucceeded, target: target)
        statusHandler(.succeeded(target))

        DispatchQueue.main.asyncAfter(deadline: .now() + environment.clipboardRestoreDelay) {
            previousPasteboard.restore(to: pasteboard)
            FileEventLog.append("format_clipboard_restored")
        }
    }

    private func waitForCopiedText(on pasteboard: NSPasteboard, previousChangeCount: Int) -> String {
        for _ in 0..<16 {
            Thread.sleep(forTimeInterval: 0.05)
            if pasteboard.changeCount != previousChangeCount {
                break
            }
        }
        return pasteboard.string(forType: .string) ?? ""
    }
}
