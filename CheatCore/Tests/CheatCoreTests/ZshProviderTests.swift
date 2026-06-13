import Foundation
import Testing
@testable import CheatCore

@Suite("ZshProvider")
struct ZshProviderTests {
    @Test("Missing config still returns curated defaults without throwing")
    func curatedDefaultsWithoutConfig() throws {
        let sheet = try ZshProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))

        #expect(sheet.count > 10)

        let lineEditing = sheet.sections.first { $0.title == "Line editing" }
        #expect(lineEditing != nil)

        let historySearch = lineEditing?.shortcuts.first { $0.action == "History search" }
        #expect(historySearch != nil)
    }

    @Test("Function parser picks up name and leading comment description")
    func parsesFunctionWithComment() {
        let text = """
        # Spin a parallel agent
        # second comment line
        agent() {
            echo hi
        }

        function teardown {
            echo bye
        }
        """
        let shortcuts = ZshProvider.parseFunctions(text)

        let agent = shortcuts.first { $0.keys == "agent" }
        #expect(agent?.action == "Spin a parallel agent")
        #expect(agent?.source == .custom)

        let teardown = shortcuts.first { $0.keys == "teardown" }
        #expect(teardown != nil)
    }

    @Test("Alias parser strips quotes from the target")
    func parsesAliases() {
        let text = """
        # File listing
        alias ls="eza --icons"
        alias gs='git status'
        not an alias line
        """
        let shortcuts = ZshProvider.parseAliases(text)

        #expect(shortcuts.first { $0.keys == "ls" }?.action == "eza --icons")
        #expect(shortcuts.first { $0.keys == "gs" }?.action == "git status")
        #expect(shortcuts.allSatisfy { $0.source == .custom })
    }
}
