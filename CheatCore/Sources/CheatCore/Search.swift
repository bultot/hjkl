import Foundation

/// One shortcut match in a global search, carrying enough context to render it
/// under its app and to jump back to that app's tab.
public struct SearchHit: Identifiable, Sendable, Hashable {
    public let sheetID: String
    public let sheetTitle: String
    public let symbol: String?
    public let sectionTitle: String
    public let shortcut: Shortcut

    /// Stable across loads (sheet + section + shortcut), good for selection/scroll.
    public var id: String { sheetID + "\u{1}" + sectionTitle + "\u{1}" + shortcut.id }

    public init(sheetID: String, sheetTitle: String, symbol: String?, sectionTitle: String, shortcut: Shortcut) {
        self.sheetID = sheetID
        self.sheetTitle = sheetTitle
        self.symbol = symbol
        self.sectionTitle = sectionTitle
        self.shortcut = shortcut
    }
}

/// Matches for one app, in original sheet order.
public struct SearchGroup: Identifiable, Sendable, Hashable {
    public let sheetID: String
    public let title: String
    public let symbol: String?
    public let hits: [SearchHit]

    public var id: String { sheetID }
    public var count: Int { hits.count }

    public init(sheetID: String, title: String, symbol: String?, hits: [SearchHit]) {
        self.sheetID = sheetID
        self.title = title
        self.symbol = symbol
        self.hits = hits
    }
}

/// Search every sheet for `query`, grouped by app in the given sheet order.
///
/// A shortcut matches when the query is a substring (case-insensitive) of its
/// action, its keys, or the app's name. So typing an app name (e.g. "aero")
/// surfaces every shortcut for that app, while typing an action narrows within.
/// An empty/whitespace query returns no groups (callers show a prompt instead).
public func searchSheets(_ sheets: [ShortcutSheet], query: String) -> [SearchGroup] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return [] }

    return sheets.compactMap { sheet -> SearchGroup? in
        let appMatches = sheet.title.lowercased().contains(q) || sheet.id.lowercased().contains(q)
        var hits: [SearchHit] = []
        for section in sheet.sections {
            for sc in section.shortcuts where appMatches
                || sc.action.lowercased().contains(q)
                || sc.keys.lowercased().contains(q) {
                hits.append(SearchHit(
                    sheetID: sheet.id, sheetTitle: sheet.title, symbol: sheet.symbol,
                    sectionTitle: section.title, shortcut: sc
                ))
            }
        }
        return hits.isEmpty ? nil : SearchGroup(
            sheetID: sheet.id, title: sheet.title, symbol: sheet.symbol, hits: hits
        )
    }
}
