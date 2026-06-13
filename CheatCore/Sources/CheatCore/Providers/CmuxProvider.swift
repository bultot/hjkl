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
        var sections = Self.builtInSections

        if let custom = try loadCustomCommands(configPath: configPath), !custom.shortcuts.isEmpty {
            sections.append(custom)
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Custom commands

    /// Parse the `commands[]` array from cmux.json into a "Custom Commands" section.
    /// Returns nil when the config file is missing (built-ins are still useful).
    private func loadCustomCommands(configPath: URL?) throws -> Section? {
        let url: URL
        do {
            url = try resolvedPath(configPath)
        } catch ProviderError.configNotFound {
            return nil
        }

        let raw: Data
        do {
            raw = try Data(contentsOf: url)
        } catch {
            // File vanished between resolution and read: treat as absent.
            return nil
        }

        let stripped = Self.stripJSONCComments(raw)

        let root: [String: Any]
        do {
            let object = try JSONSerialization.jsonObject(with: stripped)
            guard let dict = object as? [String: Any] else {
                throw ProviderError.parseFailed("cmux.json root is not an object")
            }
            root = dict
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.parseFailed("cmux.json: \(error.localizedDescription)")
        }

        guard let commands = root["commands"] as? [[String: Any]] else {
            return nil
        }

        var shortcuts: [Shortcut] = []
        for command in commands {
            guard let name = command["name"] as? String, !name.isEmpty else { continue }
            let description = command["description"] as? String
            let action = name + (description.map { " — \($0)" } ?? "")
            shortcuts.append(Shortcut(keys: keys(for: command), action: action, source: .custom))
        }

        guard !shortcuts.isEmpty else { return nil }
        return Section(title: "Custom Commands", shortcuts: shortcuts)
    }

    /// A command's own `shortcut` if it defines one, else the command-palette key.
    /// cmux launches custom commands from the palette (⌘⇧P), so that is the
    /// real keystroke to surface rather than a generic "palette" label.
    private func keys(for command: [String: Any]) -> String {
        if let combo = command["shortcut"] as? String, !combo.isEmpty {
            return KeyFormatting.chord(fromCombo: combo)
        }
        if let chord = command["shortcut"] as? [String], !chord.isEmpty {
            // A chorded binding (e.g. ["cmd+k", "c"]): format each stroke, join with a thin space.
            return chord.map { KeyFormatting.chord(fromCombo: $0) }.joined(separator: " ")
        }
        return Self.commandPaletteKey
    }

    /// cmux default for the `commandPalette` action.
    static let commandPaletteKey = "⌘⇧P"

    // MARK: - JSONC comment stripping

    /// Remove `//` line comments from JSONC, leaving `//` inside JSON strings intact.
    /// Scans character by character, tracking string state and `\` escapes.
    static func stripJSONCComments(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)

        var inString = false
        var escaped = false
        var i = 0
        let n = bytes.count

        let slash: UInt8 = 0x2F      // /
        let backslash: UInt8 = 0x5C  // \
        let quote: UInt8 = 0x22      // "
        let newline: UInt8 = 0x0A    // \n

        while i < n {
            let c = bytes[i]

            if inString {
                out.append(c)
                if escaped {
                    escaped = false
                } else if c == backslash {
                    escaped = true
                } else if c == quote {
                    inString = false
                }
                i += 1
                continue
            }

            // Outside a string.
            if c == quote {
                inString = true
                out.append(c)
                i += 1
                continue
            }

            if c == slash, i + 1 < n, bytes[i + 1] == slash {
                // Skip from `//` to end of line (keep the newline for line accounting).
                i += 2
                while i < n, bytes[i] != newline {
                    i += 1
                }
                continue
            }

            out.append(c)
            i += 1
        }

        return Data(out)
    }

    // MARK: - Built-in sections

    static let builtInSections: [Section] = [
        Section(title: "Workspaces", shortcuts: [
            Shortcut(keys: "⌘N", action: "New workspace", essential: true),
            Shortcut(keys: "⌘1–9", action: "Select workspace 1–9", essential: true),
            Shortcut(keys: "⌃⌘[", action: "Previous workspace"),
            Shortcut(keys: "⌃⌘]", action: "Next workspace"),
            Shortcut(keys: "⌘⇧G", action: "Group selected workspaces"),
            Shortcut(keys: "⌘⇧W", action: "Close workspace"),
            Shortcut(keys: "⌘⇧U", action: "Jump to latest unread", essential: true),
        ]),
        Section(title: "Panes & Surfaces", shortcuts: [
            Shortcut(keys: "⌘D", action: "Split right", essential: true),
            Shortcut(keys: "⌘T", action: "New surface"),
            Shortcut(keys: "⌥⌘←", action: "Focus pane left"),
            Shortcut(keys: "⌥⌘→", action: "Focus pane right"),
            Shortcut(keys: "⌘W", action: "Close tab"),
            Shortcut(keys: "⌘B", action: "Toggle sidebar"),
        ]),
        // Terminal helpers (~/.local/bin) for the worktree-agent workflow. These
        // are shell commands, not cmux keybindings — the keys column shows what
        // you type. Run from inside a cmux terminal in the project.
        Section(title: "Worktree CLI", shortcuts: [
            Shortcut(keys: "ccw-main", action: "Open the cockpit (Main layout) in the project group", essential: true, source: .custom),
            Shortcut(keys: "ccw <proj> <name>", action: "Spawn an agent worktree (branch agent/<name>) in the group", essential: true, source: .custom),
            Shortcut(keys: "ccw-done [name]", action: "Land agent/<name> into trunk, remove worktree, close tab", source: .custom),
            Shortcut(keys: "ccw-purge [-f]", action: "List or remove merged/dead agent worktrees", source: .custom),
        ]),
    ]
}
