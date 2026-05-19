import AppKit
import ApplicationServices

enum TargetDetector {
    static func current() -> TargetApp {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return .unsupported(name: "Unknown")
        }

        let bundleIdentifier = app.bundleIdentifier
        let appName = app.localizedName ?? app.bundleURL?.lastPathComponent ?? "Unknown"
        let browserURL = BrowserURLReader.activeURL(
            forBundleIdentifier: bundleIdentifier,
            appName: appName,
            processIdentifier: app.processIdentifier
        )

        return detect(bundleIdentifier: bundleIdentifier, appName: appName, browserURL: browserURL)
    }

    static func detect(bundleIdentifier: String?, appName: String, browserURL: String?) -> TargetApp {
        let bundle = bundleIdentifier?.lowercased() ?? ""
        let name = appName.lowercased()
        let url = browserURL?.lowercased() ?? ""

        if bundle.contains("slack") || name.contains("slack") {
            return .slack
        }

        if bundle.contains("superhuman") || name.contains("superhuman") {
            return .superhuman
        }

        let isChrome = bundle == "com.google.chrome" || name.contains("chrome")
        let isSafari = bundle == "com.apple.safari" || name.contains("safari")

        if isChrome || isSafari {
            if url.contains("chatgpt.com") || url.contains("chat.openai.com") {
                return .chatGPT
            }

            if url.contains("docs.google.com/document") {
                return .googleDocs
            }

            return .browser(name: isChrome ? "Chrome" : "Safari")
        }

        return .unsupported(name: appName)
    }
}

enum BrowserURLReader {
    static func activeURL(
        forBundleIdentifier bundleIdentifier: String?,
        appName: String,
        processIdentifier: pid_t? = nil
    ) -> String? {
        let bundle = bundleIdentifier?.lowercased() ?? ""
        if bundle == "com.google.chrome" || appName.lowercased().contains("chrome") {
            if let processIdentifier,
               let url = accessibilityAddressBarValue(forProcessIdentifier: processIdentifier) {
                return url
            }
            return runAppleScriptWithTimeout("tell application \"Google Chrome\" to return URL of active tab of front window")
        }

        if bundle == "com.apple.safari" || appName.lowercased().contains("safari") {
            if let processIdentifier,
               let url = accessibilityAddressBarValue(forProcessIdentifier: processIdentifier) {
                return url
            }
            return runAppleScriptWithTimeout("tell application \"Safari\" to return URL of front document")
        }

        return nil
    }

    private static func accessibilityAddressBarValue(forProcessIdentifier processIdentifier: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(processIdentifier)

        if let focusedWindowValue = copyAttribute(kAXFocusedWindowAttribute, from: appElement) {
            let focusedWindow = focusedWindowValue as! AXUIElement
            if let url = findAddressBarValue(in: focusedWindow) {
                return url
            }
        }

        if let windows = copyAttribute(kAXWindowsAttribute, from: appElement) as? [AnyObject] {
            for windowValue in windows {
                let window = windowValue as! AXUIElement
                if let url = findAddressBarValue(in: window) {
                    return url
                }
            }
        }

        return nil
    }

    private static func findAddressBarValue(in element: AXUIElement, depth: Int = 0) -> String? {
        guard depth < 14 else { return nil }

        let role = copyAttribute(kAXRoleAttribute, from: element) as? String
        let description = copyAttribute(kAXDescriptionAttribute, from: element) as? String ?? ""
        let title = copyAttribute(kAXTitleAttribute, from: element) as? String ?? ""
        let label = "\(description) \(title)".lowercased()

        if role == kAXTextFieldRole,
           label.contains("address") || label.contains("url"),
           let value = copyAttribute(kAXValueAttribute, from: element) as? String,
           looksLikeBrowserURL(value) {
            return value
        }

        guard let children = copyAttribute(kAXChildrenAttribute, from: element) as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let url = findAddressBarValue(in: child, depth: depth + 1) {
                return url
            }
        }

        return nil
    }

    private static func looksLikeBrowserURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("."),
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return false
        }
        return true
    }

    private static func copyAttribute(_ attribute: String, from element: AXUIElement) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as AnyObject?
    }

    private static func runAppleScriptWithTimeout(_ source: String, timeout: TimeInterval = 1.5) -> String? {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            FileEventLog.append("browser_url_read_failed_launch")
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard !process.isRunning else {
            process.terminate()
            FileEventLog.append("browser_url_read_timeout")
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        guard errorData.isEmpty else {
            FileEventLog.append("browser_url_read_failed")
            return nil
        }

        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
