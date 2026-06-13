import Foundation
import Testing
@testable import CheatCore

@Suite("NeovimProvider")
struct NeovimProviderTests {
    @Test("Loads curated defaults without throwing")
    func loadsDefaults() throws {
        let sheet = try NeovimProvider().load(configPath: nil)
        #expect(sheet.count > 30)
    }

    @Test("Motions section contains h j k l")
    func motionsSectionHasArrows() throws {
        let sheet = try NeovimProvider().load(configPath: nil)
        let motions = sheet.sections.first { $0.title == "Motions" }
        #expect(motions != nil)
        #expect(motions?.shortcuts.contains { $0.keys == "h j k l" } == true)
    }

    @Test("At least 8 shortcuts are marked essential")
    func enoughEssentials() throws {
        let sheet = try NeovimProvider().load(configPath: nil)
        let essentialCount = sheet.sections.flatMap { $0.shortcuts }.filter { $0.essential }.count
        #expect(essentialCount >= 8)
    }
}
