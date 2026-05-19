import AppKit

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let captured: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var values: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type] = data
                }
            }
            return values
        } ?? [[NSPasteboard.PasteboardType: Data]]()
        return PasteboardSnapshot(items: captured)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        for values in items {
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}

enum PasteboardService {
    static func write(_ payload: PastePayload, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        if !payload.plainText.isEmpty {
            item.setString(payload.plainText, forType: .string)
        }
        if let html = payload.html, !html.isEmpty {
            item.setString(html, forType: .html)
        }
        if let rtfData = payload.rtfData, !rtfData.isEmpty {
            item.setData(rtfData, forType: .rtf)
        }
        return pasteboard.writeObjects([item])
    }
}
