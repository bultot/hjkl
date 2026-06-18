import Foundation

/// Stable per-provider key for a hidden shortcut: `providerID\u{1}keys\u{1}action`.
/// Reuses `Shortcut.id` (`keys\u{1}action`) so identity stays consistent across
/// loads. `providerID` carries no `\u{1}`, so the key is unambiguous.
public func hiddenKey(providerID: String, shortcut: Shortcut) -> String {
    providerID + "\u{1}" + shortcut.id
}

/// Split a hidden key back into its parts for display in Settings. Returns nil if
/// the key isn't the expected three-field shape.
public func decodeHiddenKey(_ key: String) -> (providerID: String, keys: String, action: String)? {
    let parts = key.split(separator: "\u{1}", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    return (String(parts[0]), String(parts[1]), String(parts[2]))
}

/// Return a copy of `sheet` with every shortcut whose `hiddenKey` is in `hidden`
/// removed, dropping any section left empty. Mirrors `filterSheet` in Search.swift.
public func removingHidden(_ sheet: ShortcutSheet, hidden: Set<String>) -> ShortcutSheet {
    guard !hidden.isEmpty else { return sheet }
    let sections = sheet.sections.compactMap { section -> Section? in
        let kept = section.shortcuts.filter { !hidden.contains(hiddenKey(providerID: sheet.id, shortcut: $0)) }
        return kept.isEmpty ? nil : Section(title: section.title, shortcuts: kept)
    }
    return ShortcutSheet(id: sheet.id, title: sheet.title, symbol: sheet.symbol, sections: sections)
}
