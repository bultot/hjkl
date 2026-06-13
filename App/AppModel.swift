import SwiftUI
import CheatCore
import AppKit

/// App-wide state: which provider sheets are loaded, the selected tab, the live
/// filter, and the active theme. Reloads sheets from the providers on demand.
@MainActor
@Observable
final class AppModel {
    let registry = ProviderRegistry.defaults
    private(set) var sheets: [ShortcutSheet] = []
    var selectedID: String = ""
    var filter: String = ""
    var theme: Theme = .system

    var palette: Palette { Palette(theme: theme) }

    init() {
        reload()
    }

    /// (Re)load every available provider's sheet (config present or always-available).
    func reload() {
        sheets = registry.available.compactMap { provider in
            try? provider.load(configPath: nil)
        }
        .filter { $0.count > 0 }

        if selectedID.isEmpty || !sheets.contains(where: { $0.id == selectedID }) {
            selectedID = sheets.first?.id ?? ""
        }
    }

    var selectedSheet: ShortcutSheet? {
        sheets.first { $0.id == selectedID }
    }

    /// Pick the tab matching the frontmost app's bundle id (if we have a sheet for it).
    func selectForFrontmost(bundleID: String?) {
        guard let bundleID,
              let provider = registry.provider(forBundleID: bundleID),
              sheets.contains(where: { $0.id == provider.id })
        else { return }
        selectedID = provider.id
        filter = ""
    }

    /// Sections of `sheet` filtered by the current query (matches action or keys).
    func filteredSections(_ sheet: ShortcutSheet) -> [CheatCore.Section] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return sheet.sections }
        return sheet.sections.compactMap { section in
            let hits = section.shortcuts.filter {
                $0.action.lowercased().contains(q) || $0.keys.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : CheatCore.Section(title: section.title, shortcuts: hits)
        }
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
