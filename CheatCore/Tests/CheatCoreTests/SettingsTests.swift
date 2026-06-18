import Testing
import Foundation
@testable import CheatCore

@Suite("Settings")
struct SettingsTests {
    /// Unique temp directory per run so tests don't share state on disk.
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "hjkl-test-\(ProcessInfo.processInfo.processIdentifier)-\(UInt64(Date().timeIntervalSince1970 * 1_000_000))"
            )
    }

    @Test("fresh load() seeds non-empty apps including cmux and aerospace")
    func freshLoadSeeds() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        #expect(!store.settings.apps.isEmpty)
        let ids = Set(store.settings.apps.map(\.id))
        #expect(ids.contains("cmux"))
        #expect(ids.contains("aerospace"))
    }

    @Test("defaults: Gruvbox Material Dark theme, hold-to-peek off, toggle on")
    func themeDefault() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        #expect(store.settings.themeID == "gruvbox-material-dark")
        #expect(store.settings.holdToPeekEnabled == false)
        #expect(store.settings.toggleEnabled == true)
    }

    @Test("toggling enabled persists across reload")
    func togglePersists() {
        let dir = tempDir()
        let store = SettingsStore(directory: dir)
        store.load()
        store.setEnabled("cmux", false)
        store.save()

        let reloaded = SettingsStore(directory: dir)
        reloaded.load()
        #expect(reloaded.entry("cmux")?.enabled == false)
    }

    @Test("seed merge preserves a disabled entry")
    func seedMergePreserves() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        store.setEnabled("aerospace", false)
        store.setConfigPathOverride("aerospace", "/tmp/custom.toml")

        store.seed(from: .defaults)

        #expect(store.entry("aerospace")?.enabled == false)
        #expect(store.entry("aerospace")?.configPathOverride == "/tmp/custom.toml")
    }

    @Test("fresh load() seeds the default context priority")
    func contextPriorityDefault() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        #expect(store.settings.contextPriority == ContextSource.defaultPriority)
    }

    @Test("context priority persists across reload")
    func contextPriorityPersists() {
        let dir = tempDir()
        let store = SettingsStore(directory: dir)
        store.load()
        store.setContextPriority([.frontmostBundle, .attachedTmux, .cmuxPaneProbe])
        store.save()

        let reloaded = SettingsStore(directory: dir)
        reloaded.load()
        #expect(reloaded.settings.contextPriority == [.frontmostBundle, .attachedTmux, .cmuxPaneProbe])
    }

    @Test("load() normalizes a partial stored context priority")
    func contextPriorityNormalizedOnLoad() {
        let dir = tempDir()
        let store = SettingsStore(directory: dir)
        store.load()
        store.setContextPriority([.frontmostBundle])   // partial
        store.save()

        let reloaded = SettingsStore(directory: dir)
        reloaded.load()
        #expect(reloaded.settings.contextPriority == [.frontmostBundle, .cmuxPaneProbe, .attachedTmux])
    }

    @Test("legacy JSON without contextPriority decodes to default")
    func legacyContextPriority() throws {
        let legacy = #"{"apps":[],"themeID":"tokyo-night"}"#
        let decoded = try JSONDecoder().decode(HjklSettings.self, from: Data(legacy.utf8))
        #expect(decoded.contextPriority == ContextSource.defaultPriority)
    }

    @Test("an unknown context source string is dropped, not fatal")
    func unknownContextSourceDropped() throws {
        let json = #"{"contextPriority":["attached-tmux","bogus","frontmost-bundle"]}"#
        let decoded = try JSONDecoder().decode(HjklSettings.self, from: Data(json.utf8))
        #expect(decoded.contextPriority == [.attachedTmux, .frontmostBundle])
    }

    @Test("seed drops unknown ids and keeps registry order")
    func seedDropsUnknown() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        // Inject a stale entry, then re-seed from defaults.
        store.setTheme("tokyo-night")
        store.seed(from: .defaults)
        let ids = store.settings.apps.map(\.id)
        let registryIDs = ProviderRegistry.defaults.providers.map(\.id)
        #expect(ids == registryIDs)
        #expect(store.settings.themeID == "tokyo-night")
    }
}
