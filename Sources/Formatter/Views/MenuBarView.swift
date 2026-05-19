import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.status.label)
                .font(.headline)

            Text("Hotkey: \(model.preferences.hotKey.compactDisplayName)")
                .foregroundStyle(.secondary)

            Divider()

            Button("Format Selection Now") {
                model.formatNow()
            }
            .keyboardShortcut(.space, modifiers: [.control, .option])

            Toggle("Enabled", isOn: Binding(
                get: { model.preferences.isEnabled },
                set: { model.preferences.isEnabled = $0 }
            ))

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            if !model.accessibilityTrusted {
                Button("Request Accessibility") {
                    model.requestAccessibilityPermission()
                }
            }

            Button("Refresh Status") {
                model.refreshPermissionStatus()
                model.refreshOllamaStatus()
            }

            Button("Quit Formatter") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }
}
