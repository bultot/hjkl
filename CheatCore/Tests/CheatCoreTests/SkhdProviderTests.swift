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

    private func actions(_ sheet: ShortcutSheet) -> [String] {
        sheet.sections.flatMap { $0.shortcuts.map(\.action) }
    }

    @Test("tab is labeled yabai")
    func labeledYabai() throws {
        let sheet = try loadSheet()
        #expect(sheet.title == "yabai")
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
        #expect(keys.contains { $0.contains("⌃") && $0.contains("⌘") })
    }

    @Test("humanizes space focus")
    func humanizesSpaceFocus() throws {
        let sheet = try loadSheet()
        #expect(actions(sheet).contains("Focus space 1"))
    }

    @Test("humanizes directional window focus")
    func humanizesWindowFocus() throws {
        let sheet = try loadSheet()
        #expect(actions(sheet).contains("Focus left"))
        #expect(actions(sheet).contains("Focus right"))
    }

    @Test("humanizes send-window-to-space chain")
    func humanizesSendWindow() throws {
        let sheet = try loadSheet()
        #expect(actions(sheet).contains { $0.contains("Send window") && $0.contains("1") })
    }

    @Test("non-yabai command uses its inline comment as the label")
    func usesInlineComment() throws {
        let sheet = try loadSheet()
        #expect(actions(sheet).contains { $0.localizedCaseInsensitiveContains("toggle yabai on/off") })
    }

    @Test("keeps a config section header as a section title")
    func keepsSectionHeader() throws {
        let sheet = try loadSheet()
        #expect(sheet.sections.contains { $0.title.localizedCaseInsensitiveContains("focus space") })
    }

    @Test("service sub-mode produces an enter action and a bare-key resize")
    func serviceSubMode() throws {
        let sheet = try loadSheet()
        #expect(actions(sheet).contains { $0.localizedCaseInsensitiveContains("service") })
        // a mode-scoped resize binding (bare H key, no global modifiers)
        let resize = sheet.sections
            .flatMap(\.shortcuts)
            .first { $0.action.hasPrefix("Resize") }
        let unwrapped = try #require(resize)
        #expect(unwrapped.keys == "H" || unwrapped.keys.contains("H"))
    }

    @Test("a command that chains with ; is not mistaken for a mode switch")
    func commandChainNotModeSwitch() throws {
        let sheet = try loadSheet()
        // `service < b : yabai -m space --balance ; skhd -k "escape"` must read as "Balance".
        #expect(actions(sheet).contains("Balance"))
        #expect(!actions(sheet).contains { $0.localizedCaseInsensitiveContains("Enter skhd") })
    }

    @Test("hex keycode 0x32 renders as a grave accent, not literal text")
    func hexKeycodeRenders() throws {
        let sheet = try loadSheet()
        let keys = sheet.sections.flatMap { $0.shortcuts.map(\.keys) }
        #expect(keys.contains { $0.contains("`") })
        #expect(!keys.contains { $0.localizedCaseInsensitiveContains("0x32") })
    }

    @Test("parsed bindings are tagged as custom")
    func taggedCustom() throws {
        let sheet = try loadSheet()
        let sources = Set(sheet.sections.flatMap { $0.shortcuts.map(\.source) })
        #expect(sources == [.custom])
    }
}
