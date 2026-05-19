import Foundation

enum OllamaStatus: Equatable {
    case unknown
    case unavailable
    case available(models: [String])

    var label: String {
        switch self {
        case .unknown:
            return "Checking..."
        case .unavailable:
            return "Ollama unavailable"
        case .available(let models):
            if let first = models.first {
                return "Ollama ready: \(first)"
            }
            return "Ollama ready, no models"
        }
    }

    var preferredModel: String? {
        switch self {
        case .available(let models):
            return models.first
        case .unknown, .unavailable:
            return nil
        }
    }
}
