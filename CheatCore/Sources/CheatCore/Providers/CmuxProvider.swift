import Foundation

/// Shortcuts for cmux: custom commands parsed from cmux.json plus built-in keys.
public struct CmuxProvider: ShortcutProvider {
    public init() {}

    public let id = "cmux"
    public let displayName = "cmux"
    public let symbol = "rectangle.split.2x1"
    public let matchBundleIDs = ["com.cmuxterm.app"]
    public let alwaysAvailable = false
    public var defaultConfigPath: URL? { homePath(".config/cmux/cmux.json") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        // TODO(phase1): parse cmux.json `commands[]` (strip // comments) and merge
        // with the built-in cmux shortcut table.
        let url = try resolvedPath(configPath)
        _ = url
        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: [])
    }
}
