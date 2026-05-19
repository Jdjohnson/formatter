import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var hotKey: HotKeyDefinition {
        didSet { saveHotKey(hotKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.isEnabled) == nil {
            defaults.set(true, forKey: Keys.isEnabled)
        }
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.hotKey = Self.loadHotKey(defaults: defaults)
    }

    func useDefaultHotKey() {
        hotKey = .defaultValue
    }

    func useHomeKey() {
        hotKey = .home
    }

    private func saveHotKey(_ definition: HotKeyDefinition) {
        guard let data = try? JSONEncoder().encode(definition) else { return }
        defaults.set(data, forKey: Keys.hotKey)
    }

    private static func loadHotKey(defaults: UserDefaults) -> HotKeyDefinition {
        guard
            let data = defaults.data(forKey: Keys.hotKey),
            let definition = try? JSONDecoder().decode(HotKeyDefinition.self, from: data)
        else {
            return .defaultValue
        }
        return definition
    }

    private enum Keys {
        static let isEnabled = "formatter.isEnabled"
        static let hotKey = "formatter.hotKey"
    }
}
