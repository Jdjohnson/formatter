import XCTest
@testable import Formatter

final class TargetDetectorTests: XCTestCase {
    func testSlackDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack", browserURL: nil),
            .slack
        )
    }

    func testSuperhumanDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.superhuman.mail", appName: "Superhuman", browserURL: nil),
            .superhuman
        )
    }

    func testChromeChatGPTDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", browserURL: "https://chatgpt.com/c/123"),
            .chatGPT
        )
    }

    func testChromeGoogleDocsDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", browserURL: "https://docs.google.com/document/d/123/edit"),
            .googleDocs
        )
    }

    func testGenericBrowserDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.apple.Safari", appName: "Safari", browserURL: "https://example.com"),
            .browser(name: "Safari")
        )
    }

    func testUnsupportedDetection() {
        XCTAssertEqual(
            TargetDetector.detect(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", browserURL: nil),
            .unsupported(name: "Xcode")
        )
    }
}
