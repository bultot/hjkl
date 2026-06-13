import Foundation
import Testing
@testable import CheatCore

@Suite("CmuxProvider")
struct CmuxProviderTests {
    private var fixtureURL: URL {
        Bundle.module.url(forResource: "Fixtures/cmux.json", withExtension: nil)!
    }

    @Test("Custom Commands section parses Agent Worktree from the fixture")
    func customCommandsContainAgentWorktree() throws {
        let sheet = try CmuxProvider().load(configPath: fixtureURL)

        let custom = sheet.sections.first { $0.title == "Custom Commands" }
        let match = custom?.shortcuts.first { $0.action.hasPrefix("Agent Worktree") }

        #expect(custom != nil)
        #expect(match != nil)
    }

    @Test("Custom commands without a shortcut show the command-palette key, not \"palette\"")
    func customCommandsFallBackToPaletteKey() throws {
        let sheet = try CmuxProvider().load(configPath: fixtureURL)
        let custom = sheet.sections.first { $0.title == "Custom Commands" }
        let agent = custom?.shortcuts.first { $0.action.hasPrefix("Agent Worktree") }

        #expect(agent?.keys == "⌘⇧P")
        #expect(custom?.shortcuts.allSatisfy { $0.keys != "palette" } == true)
    }

    @Test("A command's own shortcut is formatted into glyphs")
    func customCommandShortcutIsFormatted() throws {
        let json = #"""
        {
          "commands": [
            { "name": "Deploy", "shortcut": "cmd+shift+d" }
          ]
        }
        """#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-shortcut-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let sheet = try CmuxProvider().load(configPath: url)
        let deploy = sheet.sections
            .first { $0.title == "Custom Commands" }?
            .shortcuts.first { $0.action == "Deploy" }

        #expect(deploy?.keys == "⇧⌘ D")
    }

    @Test("JSONC comment stripper handles a //-commented fixture without throwing")
    func loadsCommentedFixtureWithoutThrowing() throws {
        // The fixture is full of `//` line comments; load must not throw.
        let sheet = try CmuxProvider().load(configPath: fixtureURL)
        #expect(!sheet.sections.isEmpty)
    }

    @Test("Built-in Workspaces section includes New workspace")
    func builtInWorkspacesSectionExists() throws {
        let sheet = try CmuxProvider().load(configPath: fixtureURL)

        let workspaces = sheet.sections.first { $0.title == "Workspaces" }
        let newWorkspace = workspaces?.shortcuts.first { $0.action == "New workspace" }

        #expect(workspaces != nil)
        #expect(newWorkspace != nil)
    }

    @Test("Built-in Worktree CLI section lists ccw-main and ccw")
    func worktreeCLISectionExists() throws {
        let sheet = try CmuxProvider().load(configPath: fixtureURL)

        let cli = sheet.sections.first { $0.title == "Worktree CLI" }
        #expect(cli != nil)
        #expect(cli?.shortcuts.contains { $0.keys == "ccw-main" } == true)
        #expect(cli?.shortcuts.contains { $0.keys.hasPrefix("ccw ") } == true)
    }

    @Test("Comment stripper preserves // inside JSON strings")
    func stripperPreservesSlashesInStrings() throws {
        let input = Data(#"{ "url": "https://example.com", "x": 1 } // trailing"#.utf8)
        let stripped = CmuxProvider.stripJSONCComments(input)
        let object = try JSONSerialization.jsonObject(with: stripped) as? [String: Any]

        #expect(object?["url"] as? String == "https://example.com")
        #expect((object?["x"] as? Int) == 1)
    }
}
