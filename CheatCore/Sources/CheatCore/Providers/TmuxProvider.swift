import Foundation

/// Shortcuts for tmux: the default prefix-based keymap plus any bindings parsed
/// from the user's tmux.conf.
///
/// tmux is almost entirely two-step: you press the *prefix* (Ctrl-b by default)
/// and then a key, e.g. `⌃B %` to split a pane. The prefix can be rebound in the
/// config (`set -g prefix C-a`), so the built-in keymap is rendered against the
/// resolved prefix rather than a hardcoded one. Custom `bind` lines inherit the
/// prefix; `bind -n` (root-table) lines show the bare key with no prefix.
public struct TmuxProvider: ShortcutProvider {
    public init() {}

    public let id = "tmux"
    public let displayName = "tmux"
    public let symbol = "rectangle.split.3x1"
    public let matchBundleIDs: [String] = []   // runs inside a terminal; has no bundle of its own
    public let alwaysAvailable = false
    public let executableNames = ["tmux"]
    public var defaultConfigPath: URL? {
        // Modern tmux prefers the XDG path; fall back to the classic dotfile.
        let xdg = homePath(".config/tmux/tmux.conf")
        if FileManager.default.fileExists(atPath: xdg.path) { return xdg }
        return homePath(".tmux.conf")
    }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        let config = parseConfig(configPath: configPath)
        var sections = Self.builtInSections(prefix: config.prefix)
        if let custom = config.customSection {
            sections.append(custom)
        }
        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Config parsing

    /// tmux's out-of-the-box prefix, formatted for display.
    static let defaultPrefix = "⌃B"

    /// Parse the prefix override and `bind` lines from tmux.conf.
    /// Best-effort and defensive: never throws on a missing or malformed file.
    private func parseConfig(configPath: URL?) -> (prefix: String, customSection: Section?) {
        let url: URL
        do {
            url = try resolvedPath(configPath)
        } catch {
            return (Self.defaultPrefix, nil)
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return (Self.defaultPrefix, nil)
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { Self.tokenize($0) }
            .filter { !$0.isEmpty }

        // First pass: resolve the prefix, since a `bind` may appear before the
        // `set -g prefix` that defines it.
        var prefix = Self.defaultPrefix
        for tokens in lines {
            let cmd = tokens[0]
            guard cmd == "set" || cmd == "set-option" || cmd == "setw" || cmd == "set-window-option" else { continue }
            if let i = tokens.firstIndex(of: "prefix"), i + 1 < tokens.count {
                prefix = Self.formatKey(tokens[i + 1])
            }
        }

        // Second pass: collect custom bindings against the resolved prefix.
        var shortcuts: [Shortcut] = []
        for tokens in lines {
            let cmd = tokens[0]
            guard cmd == "bind" || cmd == "bind-key" else { continue }
            if let sc = Self.parseBind(tokens: Array(tokens.dropFirst()), prefix: prefix) {
                shortcuts.append(sc)
            }
        }

        let section = shortcuts.isEmpty
            ? nil
            : Section(title: "Custom (from config)", shortcuts: shortcuts)
        return (prefix, section)
    }

    /// Parse one `bind` invocation (tokens after the `bind`/`bind-key` word).
    /// Returns nil for bindings in tables other than the default prefix/root
    /// tables (e.g. `-T copy-mode-vi`), which belong to a different context.
    static func parseBind(tokens: [String], prefix: String) -> Shortcut? {
        var i = 0
        var root = false
        var table: String?
        while i < tokens.count, tokens[i].hasPrefix("-") {
            switch tokens[i] {
            case "-n":
                root = true
                i += 1
            case "-T":
                i += 1
                if i < tokens.count { table = tokens[i]; i += 1 }
            case "-N":
                i += 1
                if i < tokens.count { i += 1 }   // skip the note argument
            default:
                i += 1                            // -r and any other flags
            }
        }
        guard i < tokens.count else { return nil }

        let keyToken = tokens[i]
        i += 1
        let command = tokens[i...].joined(separator: " ")
        guard !command.isEmpty else { return nil }

        // Only the default prefix table and the root table map to a single keystroke.
        if let table {
            if table == "root" { root = true }
            else if table != "prefix" { return nil }
        }

        let keyDisplay = formatKey(keyToken)
        let keys = root ? keyDisplay : prefix + " " + keyDisplay
        return Shortcut(keys: keys, action: humanize(command), source: .custom)
    }

    // MARK: - Key & action formatting

    /// Convert tmux key notation (`C-a`, `M-Left`, `C-Space`, `"`, `|`) into a
    /// compact glyph string (`⌃A`, `⌥←`, `⌃␣`, `"`, `|`). Modifiers stay tight
    /// against the key (`⌃B`) so the prefix reads as one chord.
    static func formatKey(_ raw: String) -> String {
        var token = raw
        if token.hasPrefix("\\") { token = String(token.dropFirst()) }   // e.g. `\;`

        var mods = ""
        while true {
            if token.hasPrefix("C-") { mods += "⌃"; token = String(token.dropFirst(2)) }
            else if token.hasPrefix("M-") { mods += "⌥"; token = String(token.dropFirst(2)) }
            else if token.hasPrefix("S-") { mods += "⇧"; token = String(token.dropFirst(2)) }
            else { break }
        }
        return mods + baseGlyph(token)
    }

    /// Map a single tmux base key to a display glyph, reusing the shared table.
    static func baseGlyph(_ token: String) -> String {
        if token.isEmpty { return "" }
        if let g = KeyFormatting.glyphs[token.lowercased()] { return g }
        if token.count == 1 { return token.uppercased() }
        return token.prefix(1).uppercased() + token.dropFirst()
    }

    /// Turn a tmux command (`new-window`, `select-pane -L`) into a readable action.
    static func humanize(_ command: String) -> String {
        let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
        guard let head = parts.first else { return command }
        let name = head.replacingOccurrences(of: "-", with: " ")
        let capitalized = name.prefix(1).uppercased() + name.dropFirst()
        return parts.count > 1 ? capitalized + " " + parts[1] : capitalized
    }

    /// Split a config line into tokens, honoring single/double quotes and `\`
    /// escapes so keys like `'"'`, `"|"`, and `\;` survive as one token.
    static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var hasToken = false
        var inSingle = false
        var inDouble = false
        var escaped = false

        for ch in line {
            if escaped {
                current.append(ch); hasToken = true; escaped = false; continue
            }
            if ch == "\\" {
                escaped = true; hasToken = true; continue
            }
            if inSingle {
                if ch == "'" { inSingle = false } else { current.append(ch) }
                continue
            }
            if inDouble {
                if ch == "\"" { inDouble = false } else { current.append(ch) }
                continue
            }
            switch ch {
            case "'": inSingle = true; hasToken = true
            case "\"": inDouble = true; hasToken = true
            case " ", "\t":
                if hasToken { tokens.append(current); current = ""; hasToken = false }
            default:
                current.append(ch); hasToken = true
            }
        }
        if hasToken { tokens.append(current) }
        return tokens
    }

    // MARK: - Built-in defaults

    /// tmux's default keymap, rendered against the resolved `prefix`. Every entry
    /// here is a two-step "prefix then key" binding except where noted.
    static func builtInSections(prefix: String) -> [Section] {
        func pk(_ key: String) -> String { prefix + " " + key }

        return [
            Section(title: "Sessions", shortcuts: [
                Shortcut(keys: pk("D"), action: "Detach from session", essential: true),
                Shortcut(keys: pk("S"), action: "List / switch sessions", essential: true),
                Shortcut(keys: pk("$"), action: "Rename session"),
                Shortcut(keys: pk("("), action: "Previous session"),
                Shortcut(keys: pk(")"), action: "Next session"),
            ]),
            Section(title: "Windows", shortcuts: [
                Shortcut(keys: pk("C"), action: "New window", essential: true),
                Shortcut(keys: pk("0–9"), action: "Select window 0–9", essential: true),
                Shortcut(keys: pk("N"), action: "Next window"),
                Shortcut(keys: pk("P"), action: "Previous window"),
                Shortcut(keys: pk("L"), action: "Last (previous) window"),
                Shortcut(keys: pk("W"), action: "List windows", essential: true),
                Shortcut(keys: pk(","), action: "Rename window"),
                Shortcut(keys: pk("."), action: "Move window to index"),
                Shortcut(keys: pk("&"), action: "Kill window"),
                Shortcut(keys: pk("F"), action: "Find window by name"),
            ]),
            Section(title: "Panes", shortcuts: [
                Shortcut(keys: pk("%"), action: "Split left / right", essential: true),
                Shortcut(keys: pk("\""), action: "Split top / bottom", essential: true),
                Shortcut(keys: pk("←↑↓→"), action: "Select pane by direction", essential: true),
                Shortcut(keys: pk("O"), action: "Cycle to next pane"),
                Shortcut(keys: pk("Z"), action: "Toggle pane zoom", essential: true),
                Shortcut(keys: pk("X"), action: "Kill pane"),
                Shortcut(keys: pk("Space"), action: "Cycle pane layouts"),
                Shortcut(keys: pk("{"), action: "Swap pane with previous"),
                Shortcut(keys: pk("}"), action: "Swap pane with next"),
                Shortcut(keys: pk("!"), action: "Break pane into a new window"),
                Shortcut(keys: pk("Q"), action: "Show pane numbers"),
            ]),
            Section(title: "Copy & Misc", shortcuts: [
                Shortcut(keys: pk("["), action: "Enter copy / scroll mode", essential: true),
                Shortcut(keys: pk("]"), action: "Paste buffer"),
                Shortcut(keys: pk(":"), action: "Command prompt"),
                Shortcut(keys: pk("?"), action: "List all key bindings", essential: true),
                Shortcut(keys: pk("T"), action: "Show clock"),
            ]),
        ]
    }
}
