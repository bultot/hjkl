import Foundation

/// Shortcuts for skhd (the macOS hotkey daemon), parsed from `skhdrc`. skhd binds
/// keys to shell commands; in practice those commands almost always drive yabai, so
/// the tab is labeled "yabai" and yabai verbs are humanized into readable actions.
/// `# ----- title -----` comment lines become section headers. Always installed via
/// `isInstalled` (config present or `skhd`/`yabai` on PATH); never the frontmost app.
public struct SkhdProvider: ShortcutProvider {
    public init() {}

    public let id = "skhd"
    public let displayName = "yabai"
    public let symbol = "rectangle.split.2x2"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = false
    public let executableNames = ["skhd", "yabai"]
    public let appBundleNames: [String] = []

    /// skhd reads `~/.config/skhd/skhdrc` or `~/.skhdrc`. Prefer whichever exists,
    /// else the XDG location.
    public var defaultConfigPath: URL? {
        let candidates = [homePath(".config/skhd/skhdrc"), homePath(".skhdrc")]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

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
            guard !currentShortcuts.isEmpty else {
                currentShortcuts = []
                return
            }
            sections.append(Section(title: currentTitle ?? "Bindings", shortcuts: currentShortcuts))
            currentShortcuts = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Comment line -> section title.
            if line.hasPrefix("#") {
                let cleaned = cleanSectionTitle(line)
                if !cleaned.isEmpty {
                    flush()
                    currentTitle = cleaned
                }
                continue
            }

            // Mode declarations (":: default", ":: service @") produce no shortcut.
            if line.hasPrefix("::") { continue }

            if let shortcut = parseBinding(line) {
                currentShortcuts.append(shortcut)
            }
        }
        flush()

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Line parsing

    /// Parse a binding line into a `Shortcut`. Handles mode-scoped (`mode < key ...`),
    /// mode activation (`keyspec ; mode`), and normal (`keyspec : command`) forms.
    private func parseBinding(_ line: String) -> Shortcut? {
        // Strip a leading "mode < " scope so the key spec is left bare.
        var spec = line
        if let lt = spec.range(of: " < ") {
            spec = String(spec[lt.upperBound...])
        }

        // The keysym comes first; the earliest " : " (command) or " ; " (mode switch)
        // is the real separator. A command can itself chain with ";", so compare
        // positions rather than testing ";" first.
        let colon = spec.range(of: " : ")
        let semi = spec.range(of: " ; ")
        let semiFirst: Bool
        switch (colon, semi) {
        case let (c?, s?): semiFirst = s.lowerBound < c.lowerBound
        case (nil, .some): semiFirst = true
        default: semiFirst = false
        }

        if semiFirst, let semi {
            // Mode activation: "keyspec ; mode".
            let keyspec = String(spec[spec.startIndex..<semi.lowerBound]).trimmingCharacters(in: .whitespaces)
            let target = String(spec[semi.upperBound...])
            let mode = stripInlineComment(target).command.trimmingCharacters(in: .whitespaces)
            let action = mode == "default" ? "Exit mode" : "Enter \(mode) mode"
            return Shortcut(keys: formatKeys(keyspec), action: action, source: .custom)
        }

        // Normal binding: "keyspec : command".
        guard let colon else { return nil }
        let keyspec = String(spec[spec.startIndex..<colon.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rawCommand = String(spec[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !keyspec.isEmpty, !rawCommand.isEmpty else { return nil }

        let (action, essential) = humanizeCommand(rawCommand)
        return Shortcut(keys: formatKeys(keyspec), action: action, essential: essential, source: .custom)
    }

    /// Strip leading `#` and surrounding dashes/spaces from a comment header.
    private func cleanSectionTitle(_ line: String) -> String {
        var s = Substring(line)
        while s.first == "#" { s = s.dropFirst() }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: " -"))
    }

    // MARK: - Key formatting

    /// macOS virtual keycodes that show up in skhd configs as `0xNN`.
    private static let hexKeyGlyphs: [String: String] = [
        "0x32": "`", "0x2B": ",", "0x2F": ".", "0x2C": "/", "0x1B": "-",
        "0x18": "=", "0x21": "[", "0x1E": "]", "0x29": ";", "0x27": "'",
        "0x24": "↵", "0x35": "⎋", "0x30": "⇥", "0x31": "␣", "0x33": "⌫",
    ]

    /// Format a skhd key spec ("cmd + alt + ctrl - h") into a glyph chord.
    private func formatKeys(_ spec: String) -> String {
        // Modifiers are joined by "+", separated from the key by " - ".
        let parts = spec.components(separatedBy: " - ")
        var tokens: [String] = []
        if parts.count >= 2 {
            tokens += parts[0].split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let keyToken = parts.last?.trimmingCharacters(in: .whitespaces) ?? spec
        tokens.append(mapKeyToken(keyToken))
        return KeyFormatting.chord(tokens.filter { !$0.isEmpty })
    }

    /// Map a hex keycode to its glyph; pass everything else through unchanged.
    private func mapKeyToken(_ token: String) -> String {
        Self.hexKeyGlyphs[token.lowercased()] ?? Self.hexKeyGlyphs[token] ?? token
    }

    // MARK: - Command humanization

    /// Split a trailing `#` inline comment off a command. Two-space convention, but a
    /// single " #" is honored too.
    private func stripInlineComment(_ raw: String) -> (command: String, comment: String) {
        if let hash = raw.range(of: " #") {
            let command = String(raw[raw.startIndex..<hash.lowerBound]).trimmingCharacters(in: .whitespaces)
            var comment = String(raw[hash.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: " #"))
            comment = comment.trimmingCharacters(in: .whitespaces)
            return (command, comment)
        }
        return (raw, "")
    }

    /// Turn a shell command into a readable label. yabai verbs are humanized; other
    /// commands fall back to their inline comment, then the executable basename.
    /// Returns the label and whether it's an "essential" (focus) action.
    private func humanizeCommand(_ raw: String) -> (action: String, essential: Bool) {
        let (command, comment) = stripInlineComment(raw)

        // First yabai segment of an "&&"/";" chain carries the primary intent.
        let firstSegment = command
            .components(separatedBy: CharacterSet(charactersIn: "&;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? command

        if let label = humanizeYabai(firstSegment, fullCommand: command) {
            let essential = label.hasPrefix("Focus ")
            return (label, essential)
        }

        if !comment.isEmpty { return (comment.capitalizedFirst, false) }

        let exe = (firstSegment.split(separator: " ").first.map(String.init) ?? firstSegment)
        let basename = (exe as NSString).lastPathComponent
        return ("Run \(basename.isEmpty ? exe : basename)", false)
    }

    private static let directions: [String: String] =
        ["west": "left", "east": "right", "north": "up", "south": "down"]

    /// Humanize a single `yabai -m ...` command. `fullCommand` lets us detect the
    /// "send window + follow focus" idiom that spans two segments.
    private func humanizeYabai(_ segment: String, fullCommand: String) -> String? {
        let tokens = segment.split(separator: " ").map(String.init)
        guard tokens.first == "yabai", tokens.count >= 4, tokens[1] == "-m" else { return nil }
        let domain = tokens[2]               // space | window | display | ...
        let flag = tokens[3]                 // --focus | --swap | --space | --toggle | ...
        let arg = tokens.count > 4 ? tokens[4] : ""

        switch (domain, flag) {
        case ("space", "--focus"):
            return arg == "recent" ? "Focus recent space" : "Focus space \(arg)"
        case ("space", "--balance"):
            return "Balance"
        case ("space", "--rotate"):
            return "Rotate"
        case ("space", "--toggle"):
            return arg == "gap" ? "Toggle gaps" : "Toggle \(arg)"
        case ("window", "--space"):
            let follow = fullCommand.contains("space --focus")
            return follow ? "Send window → space \(arg) (follow)" : "Send window → space \(arg)"
        case ("window", "--focus"):
            return "Focus \(Self.directions[arg] ?? arg)"
        case ("window", "--swap"):
            return "Swap \(Self.directions[arg] ?? arg)"
        case ("window", "--resize"):
            return "Resize \(arg)"
        case ("window", "--toggle"):
            switch arg {
            case "zoom-fullscreen": return "Toggle fullscreen"
            case "float": return "Toggle float"
            case "split": return "Toggle split"
            default: return "Toggle \(arg)"
            }
        default:
            return nil
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
