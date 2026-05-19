import Foundation

enum DiagnosticCode: String, CaseIterable {
    case formatSucceeded
    case disabled
    case permissionMissing
    case noSelection
    case unsupportedTarget
    case parserUncertain
    case modelUnavailable
    case modelRejected
    case pasteboardWriteFailed
    case pasteFailed
    case hotKeyRegistrationFailed
}

struct DiagnosticEvent: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let code: DiagnosticCode
    let targetName: String?

    var message: String {
        switch code {
        case .formatSucceeded:
            return "Format succeeded"
        case .disabled:
            return "Formatter disabled"
        case .permissionMissing:
            return "Accessibility permission missing"
        case .noSelection:
            return "No selected text"
        case .unsupportedTarget:
            return "Unsupported target app"
        case .parserUncertain:
            return "Parser could not safely format"
        case .modelUnavailable:
            return "Ollama fallback unavailable"
        case .modelRejected:
            return "Ollama fallback rejected"
        case .pasteboardWriteFailed:
            return "Could not prepare pasteboard"
        case .pasteFailed:
            return "Could not paste into target app"
        case .hotKeyRegistrationFailed:
            return "Could not register hotkey"
        }
    }
}

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published private(set) var events: [DiagnosticEvent] = []

    func record(_ code: DiagnosticCode, target: TargetApp?) {
        let event = DiagnosticEvent(date: Date(), code: code, targetName: target?.displayName)
        events.insert(event, at: 0)
        if events.count > 20 {
            events.removeLast(events.count - 20)
        }
    }

    func containsSelectedText(_ text: String) -> Bool {
        events.contains { event in
            event.message.contains(text) || (event.targetName?.contains(text) ?? false)
        }
    }
}
