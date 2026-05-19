import Foundation

enum TargetApp: Equatable {
    case slack
    case superhuman
    case chatGPT
    case googleDocs
    case browser(name: String)
    case unsupported(name: String)

    var displayName: String {
        switch self {
        case .slack:
            return "Slack"
        case .superhuman:
            return "Superhuman"
        case .chatGPT:
            return "ChatGPT"
        case .googleDocs:
            return "Google Docs"
        case .browser(let name):
            return name
        case .unsupported(let name):
            return name
        }
    }

    var logIdentifier: String {
        switch self {
        case .slack:
            return "slack"
        case .superhuman:
            return "superhuman"
        case .chatGPT:
            return "chatgpt"
        case .googleDocs:
            return "google_docs"
        case .browser:
            return "browser"
        case .unsupported:
            return "unsupported"
        }
    }

    var isSupported: Bool {
        switch self {
        case .slack, .superhuman, .chatGPT, .googleDocs, .browser:
            return true
        case .unsupported:
            return false
        }
    }

    var prefersMarkdownPlainText: Bool {
        if case .chatGPT = self {
            return true
        }
        return false
    }
}

struct TargetSnapshot: Equatable {
    var bundleIdentifier: String?
    var appName: String
    var browserURL: String?
}
