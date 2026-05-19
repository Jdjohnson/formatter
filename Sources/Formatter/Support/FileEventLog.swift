import Foundation

enum FileEventLog {
    private static let queue = DispatchQueue(label: "com.jaradjohnson.formatter.file-event-log")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static var logURL: URL {
        let baseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Formatter", isDirectory: true)
        return baseURL.appendingPathComponent("events.log")
    }

    static func append(_ event: String) {
        let safeEvent = event
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || "_-.:".unicodeScalars.contains($0) }
            .map(String.init)
            .joined()
        let line = "\(formatter.string(from: Date())) \(safeEvent)\n"

        queue.async {
            let fileManager = FileManager.default
            let directoryURL = logURL.deletingLastPathComponent()
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            if let data = line.data(using: .utf8) {
                if fileManager.fileExists(atPath: logURL.path),
                   let handle = try? FileHandle(forWritingTo: logURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
    }
}
