import Foundation
import Testing
@testable import CheatCore

@Suite("GitProvider")
struct GitProviderTests {
    private func gitconfigURL() throws -> URL {
        try #require(Bundle.module.url(forResource: "Fixtures/gitconfig", withExtension: nil))
    }

    private func ghConfigText() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/gh-config.yml", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Curated table

    @Test("Curated sheet loads without a config and is comprehensive")
    func curatedLoads() throws {
        let sheet = try GitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        #expect(sheet.count > 40)
    }

    @Test("Covers branch switching")
    func coversSwitch() throws {
        let sheet = try GitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        let all = sheet.sections.flatMap(\.shortcuts)
        #expect(all.contains { $0.keys.contains("git switch") })
        #expect(all.contains { $0.keys == "git branch" })
    }

    @Test("Covers GitHub pull requests")
    func coversPRs() throws {
        let sheet = try GitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        let all = sheet.sections.flatMap(\.shortcuts)
        #expect(all.contains { $0.keys.hasPrefix("gh pr") })
    }

    @Test("Every curated command carries a detail explanation")
    func curatedHaveDetail() throws {
        let sheet = try GitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        let curated = sheet.sections.flatMap(\.shortcuts).filter { $0.source == .builtinDefault }
        #expect(!curated.isEmpty)
        #expect(curated.allSatisfy { ($0.detail?.isEmpty == false) })
    }

    @Test("Some curated shortcut is essential")
    func someEssential() throws {
        let sheet = try GitProvider().load(configPath: URL(fileURLWithPath: "/nonexistent"))
        #expect(sheet.sections.flatMap(\.shortcuts).contains { $0.essential })
    }

    // MARK: - Alias parsing

    @Test("Parses git aliases from the [alias] section only")
    func parsesGitAliases() throws {
        let text = try String(contentsOf: try gitconfigURL(), encoding: .utf8)
        let aliases = GitProvider.parseGitAliases(text)
        let byKeys = Dictionary(uniqueKeysWithValues: aliases.map { ($0.keys, $0) })

        #expect(byKeys["git st"]?.action == "status")
        #expect(byKeys["git lg"]?.action == "log --oneline --graph --decorate -20")
        #expect(byKeys["git sync"]?.action == "!git pull --rebase && git push")
        #expect(byKeys.values.allSatisfy { $0.source == .custom })
        // Settings outside [alias] must not leak in.
        #expect(byKeys["git editor"] == nil)
        #expect(byKeys["git default"] == nil)
    }

    @Test("Parses gh aliases from the aliases: block")
    func parsesGhAliases() throws {
        let aliases = GitProvider.parseGhAliases(try ghConfigText())
        let byKeys = Dictionary(uniqueKeysWithValues: aliases.map { ($0.keys, $0) })

        #expect(byKeys["gh co"]?.action == "pr checkout")
        #expect(byKeys["gh prc"]?.action == "pr create --fill")
        #expect(byKeys["gh bugs"]?.action == "issue list --label=\"bug\"")
        #expect(byKeys.values.allSatisfy { $0.source == .custom })
        // Keys outside the aliases block must not leak in.
        #expect(byKeys["gh git_protocol"] == nil)
        #expect(byKeys["gh pager"] == nil)
    }

    @Test("load() surfaces git aliases from the config path")
    func loadSurfacesAliases() throws {
        let sheet = try GitProvider().load(configPath: try gitconfigURL())
        let custom = sheet.sections.flatMap(\.shortcuts).filter { $0.source == .custom }
        #expect(custom.contains { $0.keys == "git lg" })
    }

    @Test("Empty alias config yields no custom shortcuts")
    func noAliases() throws {
        #expect(GitProvider.parseGitAliases("[core]\n\teditor = nvim\n").isEmpty)
        #expect(GitProvider.parseGhAliases("version: 1\ngit_protocol: ssh\n").isEmpty)
    }
}
