import Foundation

/// Errors a provider can raise while loading a config.
public enum ProviderError: Error, Sendable, CustomStringConvertible {
    case configNotFound(URL)
    case parseFailed(String)

    public var description: String {
        switch self {
        case .configNotFound(let url): "config not found: \(url.path)"
        case .parseFailed(let why): "parse failed: \(why)"
        }
    }
}

/// A source of keyboard shortcuts for one tool, read from that tool's real config.
///
/// Implementations are pure (Foundation only, no AppKit) so they're unit-testable
/// and run off the main actor. The app layer maps the frontmost app's bundle id to
/// a provider via `matchBundleIDs`; `alwaysAvailable` providers (e.g. a window
/// manager that's never frontmost) are always offered as a tab.
public protocol ShortcutProvider: Sendable {
    /// Stable id, also used as the sheet id (e.g. "cmux").
    var id: String { get }
    /// Display name for the tab (e.g. "cmux", "AeroSpace").
    var displayName: String { get }
    /// SF Symbol for the tab icon.
    var symbol: String { get }
    /// Bundle ids whose frontmost activation should select this provider.
    var matchBundleIDs: [String] { get }
    /// True when the provider should always appear as a tab regardless of focus.
    var alwaysAvailable: Bool { get }
    /// Default location of the tool's config (used for auto-detect/seed).
    var defaultConfigPath: URL? { get }
    /// CLI binaries that signal the tool is installed (looked up on PATH).
    var executableNames: [String] { get }
    /// `.app` bundle names that signal the tool is installed (in /Applications).
    var appBundleNames: [String] { get }

    /// Parse the config at `configPath` (or `defaultConfigPath` when nil) into a sheet.
    func load(configPath: URL?) throws -> ShortcutSheet
}

public extension ShortcutProvider {
    var symbol: String { "keyboard" }
    var matchBundleIDs: [String] { [] }
    var alwaysAvailable: Bool { false }
    var executableNames: [String] { [] }
    var appBundleNames: [String] { [] }

    /// Resolve the path to read: explicit override, else the provider default.
    func resolvedPath(_ configPath: URL?) throws -> URL {
        guard let url = configPath ?? defaultConfigPath else {
            throw ProviderError.parseFailed("no config path for provider \(id)")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProviderError.configNotFound(url)
        }
        return url
    }

    /// True when the tool is present: its config exists, or its binary is on PATH,
    /// or its `.app` is installed. Drives tab visibility and first-run seeding —
    /// a provider whose tool isn't installed never shows a tab.
    var isInstalled: Bool {
        if let p = defaultConfigPath, FileManager.default.fileExists(atPath: p.path) { return true }
        if Installation.hasExecutable(executableNames) { return true }
        if Installation.hasApp(appBundleNames) { return true }
        return false
    }
}

/// Convenience for building `~`-relative config paths.
public func homePath(_ rel: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appending(path: rel, directoryHint: .notDirectory)
}
