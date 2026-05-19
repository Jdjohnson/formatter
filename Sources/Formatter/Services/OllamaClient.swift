import Foundation

struct OllamaClient {
    static let `default` = OllamaClient(executablePath: "/opt/homebrew/bin/ollama")

    let executablePath: String

    func status() -> OllamaStatus {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            return .unavailable
        }

        let result = run(arguments: ["list"], timeout: 5)
        guard result.exitCode == 0 else { return .unavailable }

        let models = result.stdout
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> String? in
                let name = line.split(separator: " ").first.map(String.init)
                return name?.isEmpty == false ? name : nil
            }

        return .available(models: Array(models))
    }

    func runModel(model: String, prompt: String, timeout: TimeInterval = 12) -> String? {
        let result = run(arguments: ["run", model, prompt], timeout: timeout)
        guard result.exitCode == 0 else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(arguments: [String], timeout: TimeInterval) -> ProcessResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return ProcessResult(exitCode: -1, stdout: "", stderr: "\(error)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}
