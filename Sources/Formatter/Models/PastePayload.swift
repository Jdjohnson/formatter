import AppKit

struct PastePayload: Equatable {
    var plainText: String
    var html: String?
    var rtfData: Data?

    var hasUsefulOutput: Bool {
        !plainText.isEmpty || html?.isEmpty == false || rtfData?.isEmpty == false
    }
}
