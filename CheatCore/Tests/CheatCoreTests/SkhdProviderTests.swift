import Foundation
import Testing

@testable import CheatCore

@Suite("SkhdProvider")
struct SkhdProviderTests {
    private func fixtureURL() throws -> URL {
        try #require(
            Bundle.module.url(forResource: "Fixtures/skhdrc", withExtension: nil)
        )
    }

    private func loadSheet() throws -> ShortcutSheet {
        let provider = SkhdProvider()
        return try provider.load(configPath: try fixtureURL())
    }

    @Test("parses more than ten shortcuts")
    func parsesManyShortcuts() throws {
        let sheet = try loadSheet()
        #expect(sheet.count > 10)
    }

    @Test("formats the hyper chord with control and command glyphs")
    func formatsHyperChord() throws {
        let sheet = try loadSheet()
        let keys = sheet.sections.flatMap { $0.shortcuts.map(\.keys) }
        #expect(keys.contains { $0.contains("⌃") && $0.contains("⌥") && $0.contains("⌘") })
    }

    @Test("humanizes a yabai space focus action")
    func humanizesSpaceFocus() throws {
        let sheet = try loadSheet()
        let actions = sheet.sections.flatMap { $0.shortcuts.map(\.action) }
        #expect(actions.contains { $0.contains("Space 1") })
    }

    @Test("humanizes window focus direction (west -> left)")
    func humanizesWindowFocus() throws {
        let sheet = try loadSheet()
        let actions = sheet.sections.flatMap { $0.shortcuts.map(\.action) }
        #expect(actions.contains { $0 == "Focus left" })
    }

    @Test("send-to-space compound command reads as a move")
    func humanizesSendToSpace() throws {
        let sheet = try loadSheet()
        let actions = sheet.sections.flatMap { $0.shortcuts.map(\.action) }
        #expect(actions.contains { $0.contains("Send window") && $0.contains("1") })
    }

    @Test("maps the 0x32 hex keycode to a backtick")
    func mapsHexBacktick() throws {
        let sheet = try loadSheet()
        let keys = sheet.sections.flatMap { $0.shortcuts.map(\.keys) }
        #expect(keys.contains { $0.contains("`") })
    }

    @Test("parses service-mode bindings and the mode switch")
    func parsesServiceMode() throws {
        let sheet = try loadSheet()
        let actions = sheet.sections.flatMap { $0.shortcuts.map(\.action) }
        #expect(actions.contains { $0.contains("service mode") })
        #expect(actions.contains { $0.contains("Resize") })
    }

    @Test("section titles come from comment headers")
    func hasFocusSpaceSection() throws {
        let sheet = try loadSheet()
        #expect(sheet.sections.contains { $0.title.lowercased().contains("focus space") })
    }

    @Test("focus shortcuts are marked essential")
    func focusIsEssential() throws {
        let sheet = try loadSheet()
        let essentials = sheet.sections.flatMap { $0.shortcuts }.filter(\.essential)
        #expect(essentials.contains { $0.action.contains("Space") || $0.action.contains("Focus") })
    }
}
