import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var preferences: PreferencesStore
    @Published var status: FormatterStatus = .idle
    @Published var accessibilityTrusted: Bool = PermissionService.isAccessibilityTrusted
    @Published var ollamaStatus: OllamaStatus = .unknown

    let diagnostics = DiagnosticStore()

    private let hotKeyManager = HotKeyManager()
    private let externalTriggerService = ExternalTriggerService()
    private lazy var selectionFormatter = SelectionFormatter(
        preferences: preferences,
        diagnostics: diagnostics,
        ollamaStatusProvider: { [weak self] in self?.ollamaStatus ?? .unknown },
        statusHandler: { [weak self] status in
            Task { @MainActor in self?.status = status }
        }
    )
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.preferences = PreferencesStore()
    }

    func start() {
        FileEventLog.append("app_start")
        refreshPermissionStatus()
        refreshOllamaStatus()
        configureHotKey()
        externalTriggerService.start { [weak self] in
            Task { @MainActor in
                FileEventLog.append("external_trigger_received")
                self?.formatNow()
            }
        }

        preferences.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.configureHotKey()
                }
            }
            .store(in: &cancellables)
    }

    func stop() {
        FileEventLog.append("app_stop")
        hotKeyManager.unregister()
        externalTriggerService.stop()
    }

    func formatNow() {
        FileEventLog.append("format_requested")
        refreshPermissionStatus()
        selectionFormatter.formatSelection()
    }

    func requestAccessibilityPermission() {
        PermissionService.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    func openAccessibilitySettings() {
        PermissionService.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        PermissionService.openInputMonitoringSettings()
    }

    func refreshPermissionStatus() {
        accessibilityTrusted = PermissionService.isAccessibilityTrusted
    }

    func refreshOllamaStatus() {
        Task.detached {
            let status = OllamaClient.default.status()
            await MainActor.run {
                self.ollamaStatus = status
            }
        }
    }

    func setHotKey(_ definition: HotKeyDefinition) {
        preferences.hotKey = definition
        configureHotKey()
    }

    private func configureHotKey() {
        hotKeyManager.unregister()
        guard preferences.isEnabled else { return }

        do {
            FileEventLog.append("hotkey_register_attempt")
            try hotKeyManager.register(definition: preferences.hotKey) { [weak self] in
                Task { @MainActor in
                    FileEventLog.append("hotkey_received")
                    self?.formatNow()
                }
            }
            FileEventLog.append("hotkey_registered")
            status = .idle
        } catch {
            FileEventLog.append("hotkey_registration_failed")
            status = .failed("Hotkey could not be registered")
            diagnostics.record(.hotKeyRegistrationFailed, target: nil)
        }
    }
}
