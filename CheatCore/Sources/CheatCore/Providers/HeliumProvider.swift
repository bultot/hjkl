import Foundation

/// Shortcuts for Helium (imput's Chromium-based browser, bundle id
/// `net.imput.helium`).
///
/// Helium has no user-readable keybinding config file the way Ghostty does, so
/// this provider ships a curated set only (source: .builtinDefault): Helium's
/// own additions plus the standard Chromium macOS bindings it inherits. The
/// Helium-specific section leads, since that's why a Chromium user would open
/// the sheet at all.
public struct HeliumProvider: ShortcutProvider {
    public init() {}

    public let id = "helium"
    public let displayName = "Helium"
    public let symbol = "globe"
    public let matchBundleIDs = ["net.imput.helium"]
    public let alwaysAvailable = false
    public let appBundleNames = ["Helium"]
    public var defaultConfigPath: URL? { nil }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: Self.builtInSections)
    }

    // MARK: - Built-in sections (curated)

    static let builtInSections: [Section] = [
        // Helium's own bindings, including ones it relocates off the Chromium defaults.
        Section(title: "Helium", shortcuts: [
            Shortcut(keys: "⌘S", action: "Toggle vertical tab bar", essential: true),
            Shortcut(keys: "⌘⇧C", action: "Copy page URL"),
            Shortcut(keys: "⌘⇧E", action: "Inspect element"),
            Shortcut(keys: "⌃Tab", action: "Cycle recent tabs"),
        ]),
        Section(title: "Tabs & Windows", shortcuts: [
            Shortcut(keys: "⌘T", action: "New tab", essential: true),
            Shortcut(keys: "⌘W", action: "Close tab"),
            Shortcut(keys: "⌘⇧T", action: "Reopen closed tab", essential: true),
            Shortcut(keys: "⌘⌥→ / ⌘⌥←", action: "Next/previous tab"),
            Shortcut(keys: "⌘1–8", action: "Go to tab N"),
            Shortcut(keys: "⌘9", action: "Last tab"),
            Shortcut(keys: "⌘N", action: "New window"),
            Shortcut(keys: "⌘⇧N", action: "New private window"),
        ]),
        Section(title: "Navigation", shortcuts: [
            Shortcut(keys: "⌘L", action: "Focus address bar", essential: true),
            Shortcut(keys: "⌘[ / ⌘]", action: "Back/forward"),
            Shortcut(keys: "⌘R", action: "Reload", essential: true),
            Shortcut(keys: "⌘⇧R", action: "Hard reload"),
            Shortcut(keys: "⌘F", action: "Find on page"),
            Shortcut(keys: "⌘G / ⌘⇧G", action: "Find next/previous"),
        ]),
        Section(title: "Page & View", shortcuts: [
            Shortcut(keys: "⌘+", action: "Zoom in"),
            Shortcut(keys: "⌘-", action: "Zoom out"),
            Shortcut(keys: "⌘0", action: "Reset zoom"),
            Shortcut(keys: "⌘D", action: "Bookmark page"),
            Shortcut(keys: "⌘⇧B", action: "Toggle bookmark bar"),
            Shortcut(keys: "⌘P", action: "Print"),
        ]),
        Section(title: "Tools", shortcuts: [
            Shortcut(keys: "⌘Y", action: "History"),
            Shortcut(keys: "⌘⇧J", action: "Downloads"),
            Shortcut(keys: "⌘⌥I", action: "Developer tools"),
            Shortcut(keys: "⌘⌥U", action: "View source"),
            Shortcut(keys: "⌘,", action: "Settings"),
        ]),
    ]
}
