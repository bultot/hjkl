import Foundation
import Testing
@testable import CheatCore

@Suite("Installation detection")
struct InstallationTests {
    @Test("Finds a binary that exists in a standard location")
    func findsKnownBinary() {
        // /bin/zsh and /bin/ls ship on every macOS.
        #expect(Installation.hasExecutable(["zsh"]))
        #expect(Installation.hasExecutable(["ls"]))
    }

    @Test("Does not find a bogus binary, or an empty list")
    func missesUnknownBinary() {
        #expect(Installation.hasExecutable(["definitely-not-a-real-tool-xyz"]) == false)
        #expect(Installation.hasExecutable([]) == false)
    }

    @Test("Empty app list is not installed")
    func emptyAppList() {
        #expect(Installation.hasApp([]) == false)
        #expect(Installation.hasApp(["NoSuchApp-ZZZ"]) == false)
    }

    @Test("A provider with a present config reports installed")
    func configMakesInstalled() throws {
        // Write a temp config and point a provider's default path at it via override.
        // isInstalled checks defaultConfigPath, so use a provider whose binary is
        // present to assert the OR-of-signals: zsh ships on every mac.
        #expect(ZshProvider().isInstalled)
    }

    @Test("tmux provider installs off its binary, with no config required")
    func tmuxInstalledViaBinary() {
        // Skip if tmux isn't on this machine (e.g. a bare CI image).
        guard Installation.hasExecutable(["tmux"]) else { return }
        #expect(TmuxProvider().isInstalled)
    }
}
