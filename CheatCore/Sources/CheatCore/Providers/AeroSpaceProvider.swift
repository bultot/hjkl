import Foundation

/// Shortcuts for AeroSpace, parsed from aerospace.toml `[mode.*.binding]` tables,
/// using `#` comment lines as section headers. Always available (it's a WM, never
/// the frontmost app).
public struct AeroSpaceProvider: ShortcutProvider {
    public init() {}

    public let id = "aerospace"
    public let displayName = "AeroSpace"
    public let symbol = "macwindow.on.rectangle"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = true
    public var defaultConfigPath: URL? { homePath(".config/aerospace/aerospace.toml") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        // TODO(phase1): parse [mode.main.binding] / [mode.service.binding]; use
        // preceding `#` comments as section titles; format combos via KeyFormatting.
        let url = try resolvedPath(configPath)
        _ = url
        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: [])
    }
}
