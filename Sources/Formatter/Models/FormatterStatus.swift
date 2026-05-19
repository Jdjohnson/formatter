import Foundation

enum FormatterStatus: Equatable {
    case idle
    case working
    case succeeded(TargetApp)
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            return "Ready"
        case .working:
            return "Formatting..."
        case .succeeded(let target):
            return "Formatted for \(target.displayName)"
        case .failed(let message):
            return message
        }
    }
}
