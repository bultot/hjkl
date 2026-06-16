import Testing
import Foundation
@testable import CheatCore

@Suite("Global search")
struct SearchTests {
    private var sheets: [ShortcutSheet] {
        [
            ShortcutSheet(id: "aerospace", title: "AeroSpace", symbol: "rectangle.3.group", sections: [
                Section(title: "Workspaces", shortcuts: [
                    Shortcut(keys: "⌥ 1", action: "Focus workspace 1"),
                    Shortcut(keys: "⌥ ⇧ 1", action: "Move window to workspace 1"),
                ]),
                Section(title: "Focus", shortcuts: [
                    Shortcut(keys: "⌥ H", action: "Focus left", essential: true),
                ]),
            ]),
            ShortcutSheet(id: "neovim", title: "Neovim", symbol: "n.square", sections: [
                Section(title: "Motion", shortcuts: [
                    Shortcut(keys: "h", action: "Move left"),
                    Shortcut(keys: "G", action: "Go to bottom"),
                ]),
            ]),
        ]
    }

    @Test("Empty query returns no groups")
    func emptyQuery() {
        #expect(searchSheets(sheets, query: "").isEmpty)
        #expect(searchSheets(sheets, query: "   ").isEmpty)
    }

    @Test("Matches action text across all sheets")
    func matchesAction() {
        let groups = searchSheets(sheets, query: "left")
        #expect(groups.count == 2)                       // AeroSpace + Neovim both have a "left"
        let hits = groups.flatMap(\.hits)
        #expect(hits.count == 2)
        #expect(hits.contains { $0.shortcut.action == "Focus left" })
        #expect(hits.contains { $0.shortcut.action == "Move left" })
    }

    @Test("Matches key combo text")
    func matchesKeys() {
        let groups = searchSheets(sheets, query: "⇧")
        let hits = groups.flatMap(\.hits)
        #expect(hits.count == 1)
        #expect(hits.first?.shortcut.action == "Move window to workspace 1")
    }

    @Test("App name match surfaces every shortcut for that app")
    func matchesAppName() {
        let groups = searchSheets(sheets, query: "aero")
        #expect(groups.count == 1)
        #expect(groups.first?.sheetID == "aerospace")
        #expect(groups.first?.count == 3)                // all three AeroSpace shortcuts
    }

    @Test("Search is case-insensitive")
    func caseInsensitive() {
        #expect(searchSheets(sheets, query: "FOCUS").flatMap(\.hits).count
                == searchSheets(sheets, query: "focus").flatMap(\.hits).count)
        #expect(searchSheets(sheets, query: "FOCUS").flatMap(\.hits).isEmpty == false)
    }

    @Test("Groups preserve sheet order and hits preserve in-sheet order")
    func ordering() {
        let groups = searchSheets(sheets, query: "o")   // broad: hits in both sheets
        #expect(groups.map(\.sheetID) == ["aerospace", "neovim"])
        let aero = groups.first { $0.sheetID == "aerospace" }!
        let firstTwo = aero.hits.prefix(2).map(\.shortcut.action)
        #expect(firstTwo == ["Focus workspace 1", "Move window to workspace 1"])
    }

    @Test("No matches yields no groups")
    func noMatches() {
        #expect(searchSheets(sheets, query: "zzzzz").isEmpty)
    }

    @Test("Hit ids are unique and stable")
    func hitIDs() {
        let ids = searchSheets(sheets, query: "o").flatMap(\.hits).map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

@Suite("Current-app filter")
struct FilterSheetTests {
    private var aerospace: ShortcutSheet {
        ShortcutSheet(id: "aerospace", title: "AeroSpace", symbol: "rectangle.3.group", sections: [
            Section(title: "Workspaces", shortcuts: [
                Shortcut(keys: "⌥ 1", action: "Focus workspace 1"),
                Shortcut(keys: "⌥ ⇧ 1", action: "Move window to workspace 1"),
            ]),
            Section(title: "Focus", shortcuts: [
                Shortcut(keys: "⌥ H", action: "Focus left", essential: true),
            ]),
        ])
    }

    @Test("Empty query returns every section unchanged")
    func emptyQuery() {
        #expect(filterSheet(aerospace, query: "") == aerospace.sections)
        #expect(filterSheet(aerospace, query: "  ") == aerospace.sections)
    }

    @Test("Matches action text and drops empty sections")
    func matchesAction() {
        let sections = filterSheet(aerospace, query: "focus")
        #expect(sections.count == 2)                       // Workspaces + Focus both retain a hit
        #expect(sections.flatMap(\.shortcuts).count == 2)
        #expect(sections.allSatisfy { !$0.shortcuts.isEmpty })
    }

    @Test("Matches key combo text")
    func matchesKeys() {
        let sections = filterSheet(aerospace, query: "⇧")
        #expect(sections.flatMap(\.shortcuts).map(\.action) == ["Move window to workspace 1"])
    }

    @Test("Does not match on the app's own name (action/keys only)")
    func ignoresAppName() {
        #expect(filterSheet(aerospace, query: "aero").isEmpty)
    }

    @Test("Filter is case-insensitive")
    func caseInsensitive() {
        #expect(filterSheet(aerospace, query: "FOCUS").flatMap(\.shortcuts).count
                == filterSheet(aerospace, query: "focus").flatMap(\.shortcuts).count)
    }

    @Test("No matches yields no sections")
    func noMatches() {
        #expect(filterSheet(aerospace, query: "zzzzz").isEmpty)
    }
}
