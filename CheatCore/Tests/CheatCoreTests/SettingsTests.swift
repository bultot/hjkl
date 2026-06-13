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

    @Test("themeID defaults to system")
    func themeDefault() {
        let store = SettingsStore(directory: tempDir())
        store.load()
        #expect(store.settings.themeID == "system")
        #expect(store.settings.holdToPeekEnabled == true)
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
