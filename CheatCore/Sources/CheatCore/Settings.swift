import Foundation

/// Per-provider settings: whether it shows as a tab and an optional config path
/// override. `id` matches a `ShortcutProvider.id` (e.g. "cmux").
public struct AppEntry: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var enabled: Bool
    /// nil → use the provider's `defaultConfigPath`.
    public var configPathOverride: String?

    public init(id: String, enabled: Bool, configPathOverride: String? = nil) {
        self.id = id
        self.enabled = enabled
        self.configPathOverride = configPathOverride
    }
}

/// The persisted app settings model. Pure value type so it stays Codable/Sendable
/// and easy to test.
public struct HjklSettings: Codable, Sendable, Hashable {
    public var apps: [AppEntry]
    /// Matches a `Theme.preset` id; default "system".
    public var themeID: String
    public var holdToPeekEnabled: Bool
    public var toggleEnabled: Bool
    /// Shortcuts the user dismissed, each `providerID\u{1}keys\u{1}action` (see
    /// `hiddenKey(providerID:shortcut:)`). Kept sorted for stable JSON diffs.
    public var hiddenShortcuts: [String]

    public init(
        apps: [AppEntry] = [],
        themeID: String = "gruvbox-material-dark",
        holdToPeekEnabled: Bool = false,
        toggleEnabled: Bool = true,
        hiddenShortcuts: [String] = []
    ) {
        self.apps = apps
        self.themeID = themeID
        self.holdToPeekEnabled = holdToPeekEnabled
        self.toggleEnabled = toggleEnabled
        self.hiddenShortcuts = hiddenShortcuts
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decodeIfPresent([AppEntry].self, forKey: .apps) ?? []
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? "gruvbox-material-dark"
        holdToPeekEnabled = try c.decodeIfPresent(Bool.self, forKey: .holdToPeekEnabled) ?? false
        toggleEnabled = try c.decodeIfPresent(Bool.self, forKey: .toggleEnabled) ?? true
        hiddenShortcuts = try c.decodeIfPresent([String].self, forKey: .hiddenShortcuts) ?? []
    }
}

/// Loads, saves, and first-run-seeds `HjklSettings` as pretty-printed JSON.
///
/// `@unchecked Sendable`: the only mutable state (`_settings`) is guarded by
/// `lock` on every access, so concurrent reads/writes are safe even though the
/// compiler can't prove it for a non-final-isolated reference type.
public final class SettingsStore: @unchecked Sendable {
    private let lock = NSLock()
    private let directory: URL
    private let fileURL: URL
    private var _settings: HjklSettings

    /// Thread-safe snapshot of the current settings.
    public private(set) var settings: HjklSettings {
        get {
            lock.lock(); defer { lock.unlock() }
            return _settings
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _settings = newValue
        }
    }

    /// - Parameter directory: where `settings.json` lives. Defaults to
    ///   Application Support/hjkl, created if missing.
    public init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        self.directory = dir
        self.fileURL = dir.appendingPathComponent("settings.json")
        self._settings = HjklSettings()
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("hjkl", isDirectory: true)
    }

    private static func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }

    /// Read `settings.json` if it exists and decodes; merge in any newly added
    /// providers without clobbering user choices. Otherwise seed fresh and save.
    public func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(HjklSettings.self, from: data) {
            settings = decoded
            seed(from: .defaults)
            save()   // persist newly merged-in providers (e.g. a freshly added tool)
        } else {
            seed(from: .defaults)
            save()
        }
    }

    /// Write the current settings to disk (pretty-printed, sorted keys).
    public func save() {
        let snapshot = settings
        guard let data = try? Self.makeEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Rebuild `apps` from `registry.providers`, merged by id with existing
    /// entries: keep an existing entry's `enabled`/`configPathOverride`; for new
    /// providers default `enabled = isInstalled || alwaysAvailable`; drop entries
    /// whose id is no longer in the registry. Order follows the registry.
    public func seed(from registry: ProviderRegistry) {
        lock.lock(); defer { lock.unlock() }
        let existing = Dictionary(
            _settings.apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        _settings.apps = registry.providers.map { provider in
            if let prior = existing[provider.id] {
                return prior
            }
            return AppEntry(
                id: provider.id,
                enabled: provider.isInstalled || provider.alwaysAvailable
            )
        }
    }

    public func setEnabled(_ id: String, _ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let i = _settings.apps.firstIndex(where: { $0.id == id }) else { return }
        _settings.apps[i].enabled = on
    }

    public func setConfigPathOverride(_ id: String, _ path: String?) {
        lock.lock(); defer { lock.unlock() }
        guard let i = _settings.apps.firstIndex(where: { $0.id == id }) else { return }
        _settings.apps[i].configPathOverride = path
    }

    public func setTheme(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        _settings.themeID = id
    }

    public func setHoldToPeek(_ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        _settings.holdToPeekEnabled = on
    }

    public func entry(_ id: String) -> AppEntry? {
        lock.lock(); defer { lock.unlock() }
        return _settings.apps.first { $0.id == id }
    }

    // MARK: hidden shortcuts

    /// The hidden-shortcut keys as a set for O(1) membership checks.
    public func hiddenSet() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return Set(_settings.hiddenShortcuts)
    }

    public func hide(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        guard !_settings.hiddenShortcuts.contains(key) else { return }
        _settings.hiddenShortcuts.append(key)
        _settings.hiddenShortcuts.sort()
    }

    public func unhide(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        _settings.hiddenShortcuts.removeAll { $0 == key }
    }

    public func unhideAll() {
        lock.lock(); defer { lock.unlock() }
        _settings.hiddenShortcuts.removeAll()
    }
}
