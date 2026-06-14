import Foundation
import Testing
@testable import CheatCore

@Suite("TmuxProvider")
struct TmuxProviderTests {
    private var fixtureURL: URL {
        Bundle.module.url(forResource: "Fixtures/tmux.conf", withExtension: nil)!
    }

    @Test("Built-in defaults render as prefix-then-key pairs")
    func builtInsArePrefixed() throws {
        // No config → default Ctrl-b prefix.
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("tmux-none-\(UUID().uuidString).conf")
        let sheet = try TmuxProvider().load(configPath: missing)

        let panes = sheet.sections.first { $0.title == "Panes" }
        let split = panes?.shortcuts.first { $0.action == "Split left / right" }
        #expect(split?.keys == "⌃B %")
    }

    @Test("A rebound prefix updates every built-in binding")
    func reboundPrefixPropagates() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)

        let sessions = sheet.sections.first { $0.title == "Sessions" }
        let detach = sessions?.shortcuts.first { $0.action == "Detach from session" }
        #expect(detach?.keys == "⌃A D")

        let panes = sheet.sections.first { $0.title == "Panes" }
        let split = panes?.shortcuts.first { $0.action == "Split left / right" }
        #expect(split?.keys == "⌃A %")
    }

    @Test("Custom bind lines inherit the resolved prefix")
    func customBindInheritsPrefix() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)
        let custom = sheet.sections.first { $0.title == "Custom (from config)" }

        let newWindow = custom?.shortcuts.first { $0.action.hasPrefix("New window") }
        #expect(newWindow?.keys == "⌃A C")

        // A quoted/literal split key survives tokenizing.
        let vsplit = custom?.shortcuts.first { $0.keys == "⌃A |" }
        #expect(vsplit != nil)
        #expect(vsplit?.action == "Split window -h")
    }

    @Test("bind -n (root table) shows the bare key with no prefix")
    func rootBindHasNoPrefix() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)
        let custom = sheet.sections.first { $0.title == "Custom (from config)" }

        let paneLeft = custom?.shortcuts.first { $0.keys == "⌥H" }
        #expect(paneLeft != nil)
        #expect(paneLeft?.action == "Select pane -L")
    }

    @Test("Bindings in other key tables are ignored")
    func otherTablesIgnored() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)
        let custom = sheet.sections.first { $0.title == "Custom (from config)" }

        // The copy-mode-vi binding must not leak into the sheet.
        #expect(custom?.shortcuts.contains { $0.action.contains("begin-selection") } == false)
    }

    @Test("Key formatting handles modifiers, named keys, and literals")
    func keyFormatting() {
        #expect(TmuxProvider.formatKey("C-b") == "⌃B")
        #expect(TmuxProvider.formatKey("C-Space") == "⌃␣")
        #expect(TmuxProvider.formatKey("M-Left") == "⌥←")
        #expect(TmuxProvider.formatKey("|") == "|")
        #expect(TmuxProvider.formatKey("\"") == "\"")
    }

    @Test("Registry exposes tmux")
    func registeredInRegistry() {
        #expect(ProviderRegistry.defaults.provider(id: "tmux") != nil)
    }

    @Test("There is no generic-shell-command section")
    func noGenericShellSection() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)

        // The old "Common commands" section of generic shell commands is gone.
        #expect(sheet.sections.contains { $0.title == "Common commands" } == false)

        // No entry anywhere is a generic shell command like `find . -name`.
        let allShortcuts = sheet.sections.flatMap { $0.shortcuts }
        #expect(allShortcuts.contains { $0.keys.hasPrefix("find . -name") } == false)
    }

    @Test("Sheet has CLI sections of raw, unprefixed tmux commands")
    func cliCommandSections() throws {
        let sheet = try TmuxProvider().load(configPath: fixtureURL)

        let sessions = sheet.sections.first { $0.title == "CLI: sessions & windows" }
        let panes = sheet.sections.first { $0.title == "CLI: panes & control" }
        #expect(sessions != nil)
        #expect(panes != nil)

        let cliShortcuts = (sessions?.shortcuts ?? []) + (panes?.shortcuts ?? [])

        // Every CLI entry is a `tmux ` invocation, not a prefix-then-key pair.
        #expect(cliShortcuts.allSatisfy { $0.keys.hasPrefix("tmux ") })
        let prefixed = cliShortcuts.contains { $0.keys.hasPrefix("⌃B ") || $0.keys.hasPrefix("⌃A ") }
        #expect(prefixed == false)

        // A reasonable number of entries, at least one flagged essential.
        #expect(cliShortcuts.count >= 18)
        #expect(cliShortcuts.contains { $0.essential } == true)
    }
}
