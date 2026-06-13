import Testing
import Foundation
@testable import CheatCore

/// Locate a bundled fixture config.
func fixture(_ name: String) -> URL {
    Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)!
}

@Suite("Foundation")
struct FoundationTests {
    @Test("KeyFormatting orders modifiers and glyphs")
    func chordFormatting() {
        #expect(KeyFormatting.chord(fromCombo: "cmd-alt-ctrl-h") == "⌃⌥⌘ H")
        #expect(KeyFormatting.chord(fromCombo: "cmd-shift-w") == "⇧⌘ W")
        #expect(KeyFormatting.chord(["esc"]) == "⎋")
    }

    @Test("Registry exposes the known providers")
    func registry() {
        let ids = ProviderRegistry.defaults.providers.map(\.id)
        #expect(ids.contains("cmux"))
        #expect(ids.contains("aerospace"))
    }

    @Test("Fixtures are present")
    func fixturesExist() {
        #expect(FileManager.default.fileExists(atPath: fixture("aerospace.toml").path))
        #expect(FileManager.default.fileExists(atPath: fixture("cmux.json").path))
    }
}
