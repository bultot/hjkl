import SwiftUI
import CheatCore
import AppKit

/// App-wide state: which provider sheets are loaded (per Settings), the selected
/// tab, the live filter, and the active theme. Reloads from providers on demand
/// and when any watched config file changes.
@MainActor
@Observable
final class AppModel {
    let registry = ProviderRegistry.defaults
    let store = SettingsStore()

    private(set) var sheets: [ShortcutSheet] = []
    var selectedID: String = ""
    var filter: String = ""
    var theme: Theme = .system

    @ObservationIgnored private var watcher: ConfigWatcher?

    var palette: Palette { Palette(theme: theme) }

    init() {
        store.load()
        applyTheme()
        reload()
    }

    // MARK: providers / sheets

    /// Providers the user has enabled in Settings whose tool is actually installed.
    /// An enabled-but-uninstalled provider never surfaces a tab (stale settings,
    /// uninstalled tool), keeping the sheet honest about what's on the machine.
    var enabledProviders: [any ShortcutProvider] {
        registry.providers.filter { (store.entry($0.id)?.enabled ?? false) && $0.isInstalled }
    }

    private func configURL(for provider: any ShortcutProvider) -> URL? {
        if let o = store.entry(provider.id)?.configPathOverride, !o.isEmpty {
            return URL(fileURLWithPath: (o as NSString).expandingTildeInPath)
        }
        return provider.defaultConfigPath
    }

    /// Rebuild the sheets (no watcher churn). Safe to call from the file watcher.
    func reloadSheets() {
        sheets = enabledProviders.compactMap { p in
            try? p.load(configPath: store.entry(p.id)?.configPathOverride.flatMap {
                $0.isEmpty ? nil : URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
            })
        }
        .filter { $0.count > 0 }
        if selectedID.isEmpty || !sheets.contains(where: { $0.id == selectedID }) {
            selectedID = sheets.first?.id ?? ""
        }
    }

    /// Full reload: rebuild sheets and re-arm the config watcher.
    func reload() {
        reloadSheets()
        refreshWatching()
    }

    private func refreshWatching() {
        let paths = enabledProviders
            .compactMap { configURL(for: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        watcher?.stop()
        guard !paths.isEmpty else { watcher = nil; return }
        let w = ConfigWatcher(paths: paths) { [weak self] in
            Task { @MainActor in self?.reloadSheets() }
        }
        w.start()
        watcher = w
    }

    var selectedSheet: ShortcutSheet? { sheets.first { $0.id == selectedID } }

    func hasSheet(_ id: String) -> Bool { sheets.contains { $0.id == id } }

    /// Select a specific provider tab if it has a sheet (used by process-aware context).
    func select(providerID: String) {
        guard hasSheet(providerID) else { return }
        selectedID = providerID
        filter = ""
    }

    func selectForFrontmost(bundleID: String?) {
        guard let bundleID,
              let provider = registry.provider(forBundleID: bundleID),
              sheets.contains(where: { $0.id == provider.id })
        else { return }
        selectedID = provider.id
        filter = ""
    }

    /// Global search across every enabled sheet, grouped by app. Empty while the
    /// query is blank (the overlay shows a prompt instead).
    var searchGroups: [SearchGroup] { searchSheets(sheets, query: filter) }

    var searchHitCount: Int { searchGroups.reduce(0) { $0 + $1.count } }

    // MARK: settings mutations

    func isEnabled(_ id: String) -> Bool { store.entry(id)?.enabled ?? false }

    func setEnabled(_ id: String, _ on: Bool) {
        store.setEnabled(id, on); store.save(); reload()
    }

    var themeID: String { store.settings.themeID }

    func applyTheme() {
        theme = Theme.presets.first { $0.id == store.settings.themeID } ?? .system
    }

    func setTheme(_ id: String) {
        store.setTheme(id); store.save(); applyTheme()
    }

    var holdToPeekEnabled: Bool { store.settings.holdToPeekEnabled }

    func setHoldToPeek(_ on: Bool) {
        store.setHoldToPeek(on); store.save()
    }

    // MARK: tab navigation

    func selectNextTab(_ delta: Int) {
        guard !sheets.isEmpty, let i = sheets.firstIndex(where: { $0.id == selectedID }) else { return }
        let n = sheets.count
        selectedID = sheets[((i + delta) % n + n) % n].id
        filter = ""
    }

    func selectTab(index: Int) {
        guard sheets.indices.contains(index) else { return }
        selectedID = sheets[index].id
        filter = ""
    }
}
