import Foundation
import Testing
@testable import CheatCore

@Suite("LazygitProvider")
struct LazygitProviderTests {
    @Test("Missing config loads curated defaults without throwing")
    func missingConfigLoadsDefaults() throws {
        let sheet = try LazygitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        #expect(sheet.count > 15)
    }

    @Test("Files section contains a Commit action")
    func filesSectionHasCommit() throws {
        let sheet = try LazygitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        let files = sheet.sections.first { $0.title == "Files" }
        let commit = files?.shortcuts.first { $0.action == "Commit" }
        #expect(files != nil)
        #expect(commit != nil)
    }

    @Test("At least one default shortcut is marked essential")
    func someShortcutIsEssential() throws {
        let sheet = try LazygitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        let essential = sheet.sections.flatMap { $0.shortcuts }.contains { $0.essential }
        #expect(essential)
    }
}
