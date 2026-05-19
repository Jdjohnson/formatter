import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            DiagnosticsView(model: model)
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
        }
        .padding()
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Formatter") {
                Toggle("Enabled", isOn: Binding(
                    get: { model.preferences.isEnabled },
                    set: { model.preferences.isEnabled = $0 }
                ))

                LabeledContent("Current hotkey") {
                    Text(model.preferences.hotKey.displayName)
                        .foregroundStyle(.secondary)
                }

                HotKeyRecorderView(definition: model.preferences.hotKey) { definition in
                    model.setHotKey(definition)
                }
                .frame(height: 44)

                HStack {
                    Button("Use Home") {
                        model.preferences.useHomeKey()
                        model.setHotKey(.home)
                    }

                    Button("Use Control + Option + Space") {
                        model.preferences.useDefaultHotKey()
                        model.setHotKey(.defaultValue)
                    }
                }
            }

            Section("Permissions") {
                StatusRow(
                    title: "Accessibility",
                    value: model.accessibilityTrusted ? "Allowed" : "Needed",
                    isGood: model.accessibilityTrusted
                )

                HStack {
                    Button("Request Accessibility") {
                        model.requestAccessibilityPermission()
                    }

                    Button("Open Accessibility Settings") {
                        model.openAccessibilitySettings()
                    }

                    Button("Open Input Monitoring") {
                        model.openInputMonitoringSettings()
                    }
                }
            }

            Section("Local Model") {
                StatusRow(
                    title: "Ollama",
                    value: model.ollamaStatus.label,
                    isGood: {
                        if case .available = model.ollamaStatus { return true }
                        return false
                    }()
                )

                Button("Refresh Ollama Status") {
                    model.refreshOllamaStatus()
                }
            }

            Section("Targets") {
                Text("Slack, Superhuman, ChatGPT in Chrome, Google Docs in Chrome, and common browser editors.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.headline)

            if model.diagnostics.events.isEmpty {
                ContentUnavailableView("No diagnostics yet", systemImage: "checkmark.circle")
            } else {
                List(model.diagnostics.events) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.message)
                        if let target = event.targetName {
                            Text(target)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text("Diagnostics record operational categories only. Selected text is never logged.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusRow: View {
    var title: String
    var value: String
    var isGood: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Label(value, systemImage: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGood ? .green : .orange)
        }
    }
}
