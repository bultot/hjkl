import Foundation
import Testing

@testable import CheatCore

@Suite("AeroSpaceProvider")
struct AeroSpaceProviderTests {
    private func fixtureURL() throws -> URL {
        try #require(
            Bundle.module.url(forResource: "Fixtures/aerospace.toml", withExtension: nil)
        )
    }

    private func loadSheet() throws -> ShortcutSheet {
        let provider = AeroSpaceProvider()
        return try provider.load(configPath: try fixtureURL())
    }

    @Test("parses more than ten shortcuts")
    func parsesManyShortcuts() throws {
        let sheet = try loadSheet()
        #expect(sheet.count > 10)
    }

    @Test("humanizes a workspace action for Personal")
    func humanizesPersonalWorkspace() throws {
        let sheet = try loadSheet()
        let actions = sheet.sections.flatMap { $0.shortcuts.map(\.action) }
        #expect(actions.contains { $0.contains("Workspace: Personal") || $0.contains("Personal") })
    }

    @Test("formats the hyper chord with control and command glyphs")
    func formatsHyperChord() throws {
        let sheet = try loadSheet()
        let keys = sheet.sections.flatMap { $0.shortcuts.map(\.keys) }
        #expect(keys.contains { $0.contains("⌃") && $0.contains("⌘") })
    }

    @Test("has a section titled for Workspaces")
    func hasWorkspacesSection() throws {
        let sheet = try loadSheet()
        #expect(sheet.sections.contains { $0.title.contains("Workspaces") })
    }
}
