import Foundation

/// Shortcuts for skhd (the hotkey daemon that usually drives yabai), parsed from
/// `~/.config/skhd/skhdrc`. Uses `#` comment lines as section headers, like the
/// AeroSpace provider. Bindings look like `cmd + alt + ctrl - h : yabai -m window
/// --focus west`; mode-prefixed bindings (`service < h : ...`) and mode switches
/// (`keysym ; mode`) are supported. Always offered as a tab when installed (it's a
/// daemon, never the frontmost app).
public struct SkhdProvider: ShortcutProvider {
    public init() {}

    public let id = "skhd"
    public let displayName = "skhd"
    public let symbol = "macwindow.on.rectangle"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = false
    public let executableNames = ["skhd"]
    public let appBundleNames: [String] = []
    public var defaultConfigPath: URL? { homePath(".config/skhd/skhdrc") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        let url = try resolvedPath(configPath)
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ProviderError.parseFailed("could not read \(url.path): \(error)")
        }

        var sections: [Section] = []
        var currentTitle: String? = nil
        var currentShortcuts: [Shortcut] = []

        func flush() {
            guard !currentShortcuts.isEmpty else { return }
            sections.append(Section(title: currentTitle ?? "Bindings", shortcuts: currentShortcuts))
            currentShortcuts = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Comment line -> section title.
            if line.hasPrefix("#") {
                let cleaned = cleanCommentTitle(line)
                if !cleaned.isEmpty {
                    flush()
                    currentTitle = cleaned
                }
                continue
            }

            // Mode declaration (`:: default`, `:: service @`): not a binding.
            if line.hasPrefix("::") { continue }

            // Strip a trailing shell comment before splitting.
            let body = stripTrailingComment(line)
            guard let (lhs, kind, rhs) = splitBinding(body) else { continue }

            // Drop the `mode <` prefix; the comment headers already group sections.
            let keysym = lhs.contains("<")
                ? String(lhs[lhs.index(after: lhs.firstIndex(of: "<")!)...]).trimmingCharacters(in: .whitespaces)
                : lhs

            let keys = formatKeysym(keysym)
            guard !keys.isEmpty else { continue }

            let label: String
            switch kind {
            case .command: label = humanizeCommand(rhs)
            case .modeSwitch: label = humanizeModeSwitch(rhs)
            }
            guard !label.isEmpty else { continue }

            let essential = label.hasPrefix("Space ") || label.hasPrefix("Focus ")
            currentShortcuts.append(Shortcut(keys: keys, action: label, essential: essential, source: .custom))
        }
        flush()

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Line splitting

    private enum BindingKind { case command, modeSwitch }

    /// A skhd binding is `keysym : command` or `keysym ; mode`. The keysym never
    /// contains `:` or `;`, so the first of either delimiter ends it.
    private func splitBinding(_ line: String) -> (lhs: String, kind: BindingKind, rhs: String)? {
        let colon = line.firstIndex(of: ":")
        let semi = line.firstIndex(of: ";")
        let (idx, kind): (String.Index, BindingKind)
        switch (colon, semi) {
        case let (c?, s?): (idx, kind) = c < s ? (c, .command) : (s, .modeSwitch)
        case let (c?, nil): (idx, kind) = (c, .command)
        case let (nil, s?): (idx, kind) = (s, .modeSwitch)
        default: return nil
        }
        let lhs = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
        let rhs = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        guard !lhs.isEmpty else { return nil }
        return (lhs, kind, rhs)
    }

    /// Strip a trailing `#` comment. skhd runs commands through a shell, so a
    /// trailing `# ...` is a shell comment, not part of the action.
    private func stripTrailingComment(_ line: String) -> String {
        guard let hash = line.range(of: " #") else { return line }
        return String(line[..<hash.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    private func cleanCommentTitle(_ line: String) -> String {
        var s = Substring(line)
        while s.first == "#" || s.first == " " { s = s.dropFirst() }
        // Comment headers are wrapped in dashes ("----- focus space -----").
        var t = String(s).trimmingCharacters(in: CharacterSet(charactersIn: " -"))
        // Drop a parenthetical aside for a tidier tab title.
        if let paren = t.firstIndex(of: "(") {
            t = String(t[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    // MARK: - Keysym formatting

    /// skhd hex keycodes that appear in window-manager configs.
    private static let hexKeys: [String: String] = [
        "0x32": "backtick", "0x2b": "comma", "0x2c": "slash", "0x2a": "backslash",
        "0x1b": "minus", "0x18": "equal",
    ]

    /// Format an skhd keysym (`cmd + alt + ctrl - 0x2B`) into glyphs (`⌃⌥⌘ ,`).
    private func formatKeysym(_ keysym: String) -> String {
        let tokens = keysym
            .split(whereSeparator: { $0 == "+" || $0 == "-" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { SkhdProvider.hexKeys[$0.lowercased()] ?? $0 }
        return KeyFormatting.chord(tokens)
    }

    // MARK: - Action humanizing

    private func direction(_ d: String) -> String {
        switch d {
        case "west": return "left"
        case "east": return "right"
        case "north": return "up"
        case "south": return "down"
        default: return d
        }
    }

    /// Turn a yabai/shell command into a readable label. Compound commands
    /// (`a && b`, `a ; b`) are reduced to their leading meaningful action.
    private func humanizeCommand(_ raw: String) -> String {
        let cmd = raw.trimmingCharacters(in: .whitespaces)

        // Send window to a space and follow it: `window --space N && space --focus N`.
        if let space = match(cmd, after: "--space "), cmd.contains("--focus") {
            return "Send window → space \(space)"
        }
        if let space = match(cmd, after: "space --focus ") {
            return space == "recent" ? "Back-and-forth space" : "Space \(space)"
        }
        if let dir = match(cmd, after: "window --focus ") {
            return "Focus \(direction(dir))"
        }
        if let dir = match(cmd, after: "window --swap ") {
            return "Swap \(direction(dir))"
        }
        if cmd.contains("--toggle zoom-fullscreen") { return "Fullscreen" }
        if cmd.contains("--toggle float") { return "Toggle float" }
        if cmd.contains("--toggle split") { return "Toggle split" }
        if cmd.contains("space --balance") { return "Balance" }
        if let deg = match(cmd, after: "space --rotate ") { return "Rotate \(deg)°" }
        if let spec = match(cmd, after: "window --resize ") {
            return resizeLabel(spec)
        }
        if cmd.contains("--restart-service") || cmd.contains("--reload") {
            return "Restart services"
        }
        // Script invocation: name the script.
        if let script = cmd.split(separator: " ").first.map(String.init),
            script.hasSuffix(".sh") {
            return "Run \((script as NSString).lastPathComponent)"
        }
        return cmd
    }

    private func resizeLabel(_ spec: String) -> String {
        // e.g. "right:-60:0" (narrower), "right:60:0" (wider), "bottom:60:0" (taller).
        let parts = spec.split(separator: ":")
        guard parts.count >= 2 else { return "Resize" }
        let edge = parts[0]
        let grow = !parts[1].hasPrefix("-")
        switch edge {
        case "right", "left": return grow ? "Resize wider" : "Resize narrower"
        case "top", "bottom": return grow ? "Resize taller" : "Resize shorter"
        default: return "Resize"
        }
    }

    private func humanizeModeSwitch(_ mode: String) -> String {
        let m = mode.trimmingCharacters(in: .whitespaces)
        if m == "default" { return "Exit service mode" }
        return "Enter \(m) mode"
    }

    /// Return the token that follows `prefix` in `cmd`, up to the next space or
    /// shell separator (`&`, `;`).
    private func match(_ cmd: String, after prefix: String) -> String? {
        guard let r = cmd.range(of: prefix) else { return nil }
        let rest = cmd[r.upperBound...]
        let token = rest.prefix { $0 != " " && $0 != "&" && $0 != ";" }
        let s = String(token).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
