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

    @Test("Comment stripper preserves // inside JSON strings")
    func stripperPreservesSlashesInStrings() throws {
        let input = Data(#"{ "url": "https://example.com", "x": 1 } // trailing"#.utf8)
        let stripped = CmuxProvider.stripJSONCComments(input)
        let object = try JSONSerialization.jsonObject(with: stripped) as? [String: Any]

        #expect(object?["url"] as? String == "https://example.com")
        #expect((object?["x"] as? Int) == 1)
    }
}
