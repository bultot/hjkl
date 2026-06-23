import Foundation

/// Where a shortcut's binding came from. Most tools ship default keymaps that the
/// config only *overrides*, so providers merge bundled defaults with parsed config.
public enum ShortcutSource: String, Sendable, Hashable, Codable {
    case builtinDefault   // the tool's out-of-the-box binding (not in the user config)
    case override         // a default the user rebound in their config
    case custom           // user-defined, no default counterpart
}

/// A single keyboard shortcut: the key combo (display-ready) and what it does.
public struct Shortcut: Identifiable, Sendable, Hashable, Codable {
    public var keys: String
    public var action: String
    /// Popular/most-used shortcuts, surfaced with emphasis.
    public var essential: Bool
    public var source: ShortcutSource
    /// Optional longer explanation of how the shortcut/command works, shown on
    /// demand (a `?` the user hovers in the overlay). nil when there's nothing to add.
    public var detail: String?

    /// Deterministic id (stable across loads → good for SwiftUI diffing and tests).
    /// `detail` is intentionally excluded: it's annotation, not identity.
    public var id: String { keys + "\u{1}" + action }

    public init(keys: String, action: String, essential: Bool = false, source: ShortcutSource = .builtinDefault, detail: String? = nil) {
        self.keys = keys
        self.action = action
        self.essential = essential
        self.source = source
        self.detail = detail
    }
}

/// A named group of shortcuts (e.g. "Workspaces", "Panes").
public struct Section: Identifiable, Sendable, Hashable, Codable {
    public var title: String
    public var shortcuts: [Shortcut]

    public var id: String { title }

    public init(title: String, shortcuts: [Shortcut]) {
        self.title = title
        self.shortcuts = shortcuts
    }
}

/// The full cheat sheet for one tool/provider.
public struct ShortcutSheet: Identifiable, Sendable, Hashable, Codable {
    /// Stable provider id (e.g. "cmux", "aerospace").
    public var id: String
    /// Display name shown in the tab.
    public var title: String
    /// SF Symbol name for the tab icon (optional).
    public var symbol: String?
    public var sections: [Section]

    public init(id: String, title: String, symbol: String? = nil, sections: [Section]) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.sections = sections
    }

    /// Total shortcut count, for empty-state handling and tests.
    public var count: Int { sections.reduce(0) { $0 + $1.shortcuts.count } }
}
