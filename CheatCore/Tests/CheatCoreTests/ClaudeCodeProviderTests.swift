import Foundation
import Testing
@testable import CheatCore

@Suite("ClaudeCodeProvider")
struct ClaudeCodeProviderTests {
    @Test("Missing config returns defaults without throwing")
    func missingConfigReturnsDefaults() throws {
        let sheet = try ClaudeCodeProvider().load(
            configPath: URL(fileURLWithPath: "/nonexistent")
        )

        #expect(sheet.count > 5)
    }

    @Test("Prompt section contains Submit message")
    func promptSectionHasSubmitMessage() throws {
        let sheet = try ClaudeCodeProvider().load(
            configPath: URL(fileURLWithPath: "/nonexistent")
        )

        let prompt = sheet.sections.first { $0.title == "Prompt" }
        let submit = prompt?.shortcuts.first { $0.action == "Submit message" }

        #expect(prompt != nil)
        #expect(submit != nil)
    }
}
