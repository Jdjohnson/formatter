import AppKit

struct HotKeyDefinition: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlagsRaw: UInt
    var keyEquivalent: String

    static let defaultValue = HotKeyDefinition(
        keyCode: 49,
        modifierFlagsRaw: NSEvent.ModifierFlags([.control, .option]).rawValue,
        keyEquivalent: "Space"
    )

    static let home = HotKeyDefinition(
        keyCode: 115,
        modifierFlagsRaw: 0,
        keyEquivalent: "Home"
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
            .intersection([.control, .option, .shift, .command])
    }

    var displayName: String {
        let flags = modifierFlags
        var pieces: [String] = []
        if flags.contains(.control) { pieces.append("Control") }
        if flags.contains(.option) { pieces.append("Option") }
        if flags.contains(.shift) { pieces.append("Shift") }
        if flags.contains(.command) { pieces.append("Command") }
        pieces.append(keyEquivalent.isEmpty ? "Key \(keyCode)" : keyEquivalent)
        return pieces.joined(separator: " + ")
    }

    var compactDisplayName: String {
        let flags = modifierFlags
        var display = ""
        if flags.contains(.control) { display += "^" }
        if flags.contains(.option) { display += "Option-" }
        if flags.contains(.shift) { display += "Shift-" }
        if flags.contains(.command) { display += "Command-" }
        return display + (keyEquivalent.isEmpty ? "Key \(keyCode)" : keyEquivalent)
    }

    func matches(event: NSEvent) -> Bool {
        UInt32(event.keyCode) == keyCode
            && event.modifierFlags.intersection([.control, .option, .shift, .command]) == modifierFlags
    }

    static func from(event: NSEvent) -> HotKeyDefinition {
        HotKeyDefinition(
            keyCode: UInt32(event.keyCode),
            modifierFlagsRaw: event.modifierFlags.intersection([.control, .option, .shift, .command]).rawValue,
            keyEquivalent: KeyCodeNames.name(for: UInt32(event.keyCode), fallback: event.charactersIgnoringModifiers)
        )
    }
}

enum KeyCodeNames {
    static func name(for keyCode: UInt32, fallback: String?) -> String {
        switch keyCode {
        case 3: return "F"
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 119: return "End"
        case 121: return "Page Down"
        case 123: return "Left Arrow"
        case 124: return "Right Arrow"
        case 125: return "Down Arrow"
        case 126: return "Up Arrow"
        default:
            return fallback?.uppercased() ?? ""
        }
    }
}
