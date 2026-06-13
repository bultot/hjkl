import Foundation
import Testing
@testable import CheatCore

@Suite("GhosttyProvider")
struct GhosttyProviderTests {
    @Test("Loading with a nonexistent config returns the curated defaults without throwing")
    func defaultsLoadWithoutConfig() throws {
        let sheet = try GhosttyProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))

        #expect(sheet.count > 15)
    }

    @Test("Default set includes New tab bound to a ⌘ chord")
    func newTabShortcutExists() throws {
        let sheet = try GhosttyProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))

        let allShortcuts = sheet.sections.flatMap { $0.shortcuts }
        let newTab = allShortcuts.first { $0.action == "New tab" }

        #expect(newTab != nil)
        #expect(newTab?.keys.contains("⌘") == true)
    }
}
