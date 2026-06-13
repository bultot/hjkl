import SwiftUI
import CheatCore
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var model: AppModel
    var onSetHoldToPeek: (Bool) -> Void = { _ in }

    @State private var openAtLogin = LoginItem.isEnabled

    var body: some View {
        TabView {
            appsTab
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 460)
    }

    // MARK: Apps

    private var appsTab: some View {
        Form {
            Section("Show these apps") {
                ForEach(model.registry.providers, id: \.id) { provider in
                    Toggle(isOn: Binding(
                        get: { model.isEnabled(provider.id) },
                        set: { model.setEnabled(provider.id, $0) }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: provider.symbol).frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(provider.displayName)
                                if let p = provider.defaultConfigPath {
                                    Text(prettyPath(p))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.replacingOccurrences(of: home, with: "~")
    }

    // MARK: General

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        openAtLogin = LoginItem.setEnabled(on)
                    }
                Text("Starts hjkl in the menu bar when you log in.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { model.themeID },
                    set: { model.setTheme($0) }
                )) {
                    ForEach(Theme.presets) { Text($0.name).tag($0.id) }
                }
            }
            Section("Hotkeys") {
                KeyboardShortcuts.Recorder("Toggle cheat sheet", name: .toggleCheatSheet)
                Toggle("Hold ⌥ to peek", isOn: Binding(
                    get: { model.holdToPeekEnabled },
                    set: { onSetHoldToPeek($0) }
                ))
                Text("When on, hold ⌥ to peek and release to dismiss. Needs Accessibility permission. Off by default so ⌥ stays free for other shortcuts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Reload all configs") {
                    Button("Reload") { model.reload() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { openAtLogin = LoginItem.isEnabled }
    }
}
