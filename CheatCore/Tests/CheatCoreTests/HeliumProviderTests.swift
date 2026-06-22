import Foundation
import Testing
@testable import CheatCore

@Suite("HeliumProvider")
struct HeliumProviderTests {
    @Test("Loading returns the curated defaults without throwing")
    func defaultsLoad() throws {
        let sheet = try HeliumProvider().load(configPath: nil)

        #expect(sheet.count > 20)
    }

    @Test("Includes the Helium-specific toggle vertical tab bar on ⌘S")
    func verticalTabBarShortcutExists() throws {
        let sheet = try HeliumProvider().load(configPath: nil)
        let all = sheet.sections.flatMap { $0.shortcuts }

        let toggle = all.first { $0.action.lowercased().contains("vertical tab") }
        #expect(toggle != nil)
        #expect(toggle?.keys == "⌘S")
    }

    @Test("Matches the Helium bundle id")
    func matchesBundleID() {
        #expect(HeliumProvider().matchBundleIDs.contains("net.imput.helium"))
    }

    @Test("Carries Helium's relocated copy-URL and inspect-element bindings")
    func relocatedBindings() throws {
        let sheet = try HeliumProvider().load(configPath: nil)
        let all = sheet.sections.flatMap { $0.shortcuts }

        let copyURL = all.first { $0.keys == "⌘⇧C" }
        let inspect = all.first { $0.keys == "⌘⇧E" }
        #expect(copyURL?.action.lowercased().contains("url") == true)
        #expect(inspect?.action.lowercased().contains("inspect") == true)
    }
}
