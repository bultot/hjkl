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
            hiddenSection
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var hiddenSection: some View {
        Section("Hidden shortcuts") {
            if model.hiddenEntries.isEmpty {
                Text("Nothing hidden yet. Hover a row and click the eye, or press ⌘⌫, to hide a shortcut you already know.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(model.hiddenEntries) { entry in
                    LabeledContent {
                        Button("Restore") { model.unhide(key: entry.key) }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.action)
                            Text("\(entry.providerName)  ·  \(entry.keys)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Restore all") { model.unhideAll() }
            }
        }
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.replacingOccurrences(of: home, with: "~")
    }

    private func contextSourceLabel(_ source: ContextSource) -> String {
        switch source {
        case .cmuxPaneProbe: "Process in cmux pane"
        case .attachedTmux: "Attached tmux session"
        case .frontmostBundle: "Frontmost app"
        }
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
            Section("Context priority") {
                ForEach(Array(model.contextPriority.enumerated()), id: \.element) { i, source in
                    HStack(spacing: 8) {
                        Text("\(i + 1).").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        Text(contextSourceLabel(source))
                        Spacer()
                        Button { model.swapContextPriority(i, i - 1) } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless).disabled(i == 0)
                        Button { model.swapContextPriority(i, i + 1) } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless).disabled(i == model.contextPriority.count - 1)
                    }
                }
                Text("When more than one matches (e.g. a terminal hosting a tmux session), the overlay opens on the highest source listed here.")
                    .font(.caption).foregroundStyle(.secondary)
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
