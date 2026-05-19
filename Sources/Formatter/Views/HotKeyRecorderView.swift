import AppKit
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    var definition: HotKeyDefinition
    var onChange: (HotKeyDefinition) -> Void

    func makeNSView(context: Context) -> RecorderField {
        let field = RecorderField()
        field.onChange = onChange
        field.definition = definition
        return field
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.onChange = onChange
        nsView.definition = definition
    }
}

final class RecorderField: NSView {
    var onChange: ((HotKeyDefinition) -> Void)?
    var definition: HotKeyDefinition = .defaultValue {
        didSet {
            needsDisplay = true
            setAccessibilityValue(definition.displayName)
        }
    }

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Record hotkey")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let next = HotKeyDefinition.from(event: event)
        isRecording = false
        onChange?(next)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press the new hotkey..." : "Click to record: \(definition.displayName)"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(x: 8, y: (bounds.height - attributed.size().height) / 2, width: bounds.width - 16, height: attributed.size().height)
        attributed.draw(in: textRect)
    }
}
