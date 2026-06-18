import Testing
import Foundation
@testable import CheatCore

@Suite("HiddenShortcuts")
struct HiddenShortcutTests {
    private func sampleSheet() -> ShortcutSheet {
        ShortcutSheet(id: "neovim", title: "Neovim", symbol: "n.circle", sections: [
            Section(title: "Motion", shortcuts: [
                Shortcut(keys: "h", action: "left"),
                Shortcut(keys: "l", action: "right"),
            ]),
            Section(title: "Windows", shortcuts: [
                Shortcut(keys: "<C-w>s", action: "split window"),
            ]),
        ])
    }

    @Test("hiddenKey is providerID + shortcut.id")
    func keyFormat() {
        let sc = Shortcut(keys: "h", action: "left")
        #expect(hiddenKey(providerID: "neovim", shortcut: sc) == "neovim\u{1}h\u{1}left")
    }

    @Test("decodeHiddenKey round-trips, including spaces in the action")
    func decodeRoundTrip() {
        let sc = Shortcut(keys: "<C-w>s", action: "split window")
        let key = hiddenKey(providerID: "neovim", shortcut: sc)
        let parts = decodeHiddenKey(key)
        #expect(parts?.providerID == "neovim")
        #expect(parts?.keys == "<C-w>s")
        #expect(parts?.action == "split window")
    }

    @Test("decodeHiddenKey returns nil for a malformed key")
    func decodeMalformed() {
        #expect(decodeHiddenKey("just-one-part") == nil)
    }

    @Test("removingHidden drops the matched shortcut, keeps the rest")
    func removesMatched() {
        let sheet = sampleSheet()
        let hidden: Set<String> = [hiddenKey(providerID: "neovim", shortcut: Shortcut(keys: "h", action: "left"))]
        let out = removingHidden(sheet, hidden: hidden)
        #expect(out.count == 2)
        let motion = out.sections.first { $0.title == "Motion" }
        #expect(motion?.shortcuts.map(\.keys) == ["l"])
    }

    @Test("removingHidden drops a section left empty")
    func dropsEmptySection() {
        let sheet = sampleSheet()
        let hidden: Set<String> = [hiddenKey(providerID: "neovim", shortcut: Shortcut(keys: "<C-w>s", action: "split window"))]
        let out = removingHidden(sheet, hidden: hidden)
        #expect(out.sections.map(\.title) == ["Motion"])
    }

    @Test("removingHidden ignores keys for a different provider")
    func differentProviderUnaffected() {
        let sheet = sampleSheet()
        let hidden: Set<String> = [hiddenKey(providerID: "tmux", shortcut: Shortcut(keys: "h", action: "left"))]
        let out = removingHidden(sheet, hidden: hidden)
        #expect(out.count == sheet.count)
    }

    @Test("removingHidden with an empty set returns the sheet unchanged")
    func emptyNoop() {
        let sheet = sampleSheet()
        #expect(removingHidden(sheet, hidden: []).count == sheet.count)
    }
}

@Suite("Settings hidden shortcuts")
struct SettingsHiddenTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hjkl-test-\(ProcessInfo.processInfo.processIdentifier)-\(UInt64(Date().timeIntervalSince1970 * 1_000_000))")
    }

    @Test("hide/unhide/unhideAll and hiddenSet behave")
    func mutations() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        store.hide("a\u{1}b\u{1}c")
        store.hide("a\u{1}b\u{1}c")   // dedup
        store.hide("x\u{1}y\u{1}z")
        #expect(store.hiddenSet() == ["a\u{1}b\u{1}c", "x\u{1}y\u{1}z"])
        store.unhide("a\u{1}b\u{1}c")
        #expect(store.hiddenSet() == ["x\u{1}y\u{1}z"])
        store.unhideAll()
        #expect(store.hiddenSet().isEmpty)
    }

    @Test("hiddenShortcuts is stored sorted")
    func storedSorted() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        store.hide("z\u{1}1\u{1}1")
        store.hide("a\u{1}1\u{1}1")
        #expect(store.settings.hiddenShortcuts == ["a\u{1}1\u{1}1", "z\u{1}1\u{1}1"])
    }

    @Test("hidden shortcuts persist across reload and survive reseed")
    func persistsAndSurvivesReseed() {
        let dir = tempDir()
        let store = SettingsStore(directory: dir)
        store.load()
        store.hide("neovim\u{1}h\u{1}left")
        store.save()

        let reloaded = SettingsStore(directory: dir)
        reloaded.load()   // load() reseeds apps from defaults
        #expect(reloaded.hiddenSet() == ["neovim\u{1}h\u{1}left"])
    }

    @Test("legacy JSON without hiddenShortcuts decodes to empty")
    func legacyDecode() throws {
        let legacy = #"{"apps":[],"themeID":"tokyo-night","holdToPeekEnabled":false,"toggleEnabled":true}"#
        let decoded = try JSONDecoder().decode(HjklSettings.self, from: Data(legacy.utf8))
        #expect(decoded.hiddenShortcuts.isEmpty)
        #expect(decoded.themeID == "tokyo-night")
    }
}
