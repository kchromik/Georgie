import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    let updater: UpdaterService
    @Bindable var uiState: AppUIState

    var body: some View {
        TabView(selection: $uiState.settingsTab) {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AboutView(updater: updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 420)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("New Windows") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Default Opacity")
                        Spacer()
                        Text(verbatim: "\(Int(settings.defaultOpacity * 100)) %")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.defaultOpacity, in: 0.2...1.0)
                }

                Picker("Default Level", selection: $settings.defaultLevel) {
                    ForEach(FloatLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }

            Section {
                Toggle("Snap to screen edges", isOn: $settings.snapToEdges)
            } header: {
                Text("Windows")
            } footer: {
                Text("Floating windows magnetically align to screen edges and corners while you drag them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Restore open windows on launch", isOn: $settings.restoreSession)
            } header: {
                Text("Session")
            } footer: {
                Text("Reopens your floating windows — and their size, position and opacity — the next time Georgie launches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch Georgie at login", isOn: $settings.launchAtLogin)
            } header: {
                Text("Startup")
            } footer: {
                Text("Starts Georgie automatically and quietly in the menu bar when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 460)
    }
}
