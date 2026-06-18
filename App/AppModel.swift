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
    /// Hidden-shortcut keys (`providerID\u{1}keys\u{1}action`). Observed render
    /// source of truth, mirrored to `store`; mutating the store alone wouldn't
    /// trigger `@Observable` updates.
    private(set) var hidden: Set<String> = []
    var selectedID: String = ""
    var filter: String = ""
    /// false → typing filters the selected app (the default); true → `/` escalated
    /// the same query to a search across every enabled app.
    var globalSearch: Bool = false
    /// Bumped each time the overlay is shown interactively. The view observes it
    /// to re-focus the search field, since the hosting view is built once and
    /// reused (so `onAppear` fires only on the first, hidden, pre-warm).
    var presentNonce: Int = 0
    var theme: Theme = .system

    @ObservationIgnored private var watcher: ConfigWatcher?

    var palette: Palette { Palette(theme: theme) }

    init() {
        store.load()
        hidden = store.hiddenSet()
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

    /// Sheets with the user's hidden shortcuts stripped out. Drives every
    /// rendered list (current-app and global search); tabs still come from raw
    /// `sheets`, so hiding every shortcut in an app leaves an empty tab rather
    /// than making the tab vanish.
    var visibleSheets: [ShortcutSheet] { sheets.map { removingHidden($0, hidden: hidden) } }

    private var visibleSelectedSheet: ShortcutSheet? { visibleSheets.first { $0.id == selectedID } }

    func hasSheet(_ id: String) -> Bool { sheets.contains { $0.id == id } }

    /// Reset to a clean browse of the current app: empty query, current-app scope.
    /// Called when the overlay is shown so each session starts ready to type.
    func resetSearch() {
        filter = ""
        globalSearch = false
    }

    /// Select a specific provider tab if it has a sheet (used by process-aware context).
    func select(providerID: String) {
        guard hasSheet(providerID) else { return }
        selectedID = providerID
        resetSearch()
    }

    func selectForFrontmost(bundleID: String?) {
        guard let bundleID,
              let provider = registry.provider(forBundleID: bundleID),
              sheets.contains(where: { $0.id == provider.id })
        else { return }
        selectedID = provider.id
        resetSearch()
    }

    /// Global search across every enabled sheet, grouped by app. Empty while the
    /// query is blank (the overlay shows a prompt instead).
    var searchGroups: [SearchGroup] { searchSheets(visibleSheets, query: filter) }

    var searchHitCount: Int { searchGroups.reduce(0) { $0 + $1.count } }

    /// The selected app's sections, narrowed to the current query (or the full
    /// sheet when the query is empty). Drives the default current-app view.
    var currentAppSections: [CheatCore.Section] {
        guard let sheet = visibleSelectedSheet else { return [] }
        return filterSheet(sheet, query: filter)
    }

    /// Visible (hidden-stripped) shortcut count for the selected app, for the footer.
    var selectedVisibleCount: Int { visibleSelectedSheet?.count ?? 0 }

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

    // MARK: hidden shortcuts

    func isHidden(providerID: String, shortcut: Shortcut) -> Bool {
        hidden.contains(hiddenKey(providerID: providerID, shortcut: shortcut))
    }

    func hide(providerID: String, shortcut: Shortcut) {
        let key = hiddenKey(providerID: providerID, shortcut: shortcut)
        hidden.insert(key)
        store.hide(key); store.save()
    }

    func unhide(key: String) {
        hidden.remove(key)
        store.unhide(key); store.save()
    }

    func unhideAll() {
        hidden.removeAll()
        store.unhideAll(); store.save()
    }

    /// Hidden shortcuts decoded for the Settings list: provider display name plus
    /// the readable keys/action, sorted by app then action. Drops keys whose
    /// provider is no longer in the registry.
    var hiddenEntries: [HiddenEntry] {
        hidden.compactMap { key -> HiddenEntry? in
            guard let parts = decodeHiddenKey(key),
                  let provider = registry.provider(id: parts.providerID) else { return nil }
            return HiddenEntry(
                key: key, providerID: parts.providerID, providerName: provider.displayName,
                keys: parts.keys, action: parts.action
            )
        }
        .sorted { ($0.providerName, $0.action) < ($1.providerName, $1.action) }
    }

    // MARK: tab navigation

    /// Move to an adjacent app tab. Drops back to current-app scope but keeps the
    /// typed query, so arrowing across apps re-applies the same search to each.
    func selectNextTab(_ delta: Int) {
        guard !sheets.isEmpty, let i = sheets.firstIndex(where: { $0.id == selectedID }) else { return }
        let n = sheets.count
        selectedID = sheets[((i + delta) % n + n) % n].id
        globalSearch = false
    }

    func selectTab(index: Int) {
        guard sheets.indices.contains(index) else { return }
        selectedID = sheets[index].id
        globalSearch = false
    }
}

/// A hidden shortcut decoded for display in Settings.
struct HiddenEntry: Identifiable {
    let key: String
    let providerID: String
    let providerName: String
    let keys: String
    let action: String
    var id: String { key }
}
