import Foundation

/// A single keyboard shortcut: the key combo (display-ready) and what it does.
public struct Shortcut: Identifiable, Sendable, Hashable, Codable {
    public var keys: String
    public var action: String

    /// Deterministic id (stable across loads → good for SwiftUI diffing and tests).
    public var id: String { keys + "\u{1}" + action }

    public init(keys: String, action: String) {
        self.keys = keys
        self.action = action
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
