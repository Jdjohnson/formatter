import Foundation
import CoreGraphics

enum KeyboardSimulator {
    @discardableResult
    static func copy() -> Bool {
        postCommand(keyCode: 8)
    }

    @discardableResult
    static func paste() -> Bool {
        postCommand(keyCode: 9)
    }

    @discardableResult
    private static func postCommand(keyCode: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        guard let keyDown, let keyUp else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
