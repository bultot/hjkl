import Foundation

/// Shortcuts for Ghostty: curated macOS default keybindings plus any
/// overrides parsed from the Ghostty config file.
///
/// Per the project owner, Ghostty's config only contains *overrides*; the
/// built-in defaults never appear there. So we ship a curated default set
/// (source: .builtinDefault) and append a "Custom (from config)" section for
/// any `keybind = ...` lines found in the config.
public struct GhosttyProvider: ShortcutProvider {
    public init() {}

    public let id = "ghostty"
    public let displayName = "Ghostty"
    public let symbol = "terminal"
    public let matchBundleIDs = ["com.mitchellh.ghostty"]
    public let alwaysAvailable = true
    public var defaultConfigPath: URL? { homePath(".config/ghostty/config") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        var sections = Self.builtInSections

        if let custom = loadOverrides(configPath: configPath), !custom.shortcuts.isEmpty {
            sections.append(custom)
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Override parsing

    /// Parse `keybind = <combo>=<action>` lines from the Ghostty config into a
    /// "Custom (from config)" section. Returns nil when the file is missing.
    /// Best-effort and defensive: never throws on a missing or malformed file.
    private func loadOverrides(configPath: URL?) -> Section? {
        let url: URL
        do {
            url = try resolvedPath(configPath)
        } catch {
            // Missing (configNotFound) or otherwise unresolvable: defaults only.
            return nil
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            // File vanished or unreadable between resolution and read.
            return nil
        }

        var shortcuts: [Shortcut] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            // Expect: keybind = <combo>=<action>
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            guard key == "keybind" else { continue }

            // Everything after the first '=' is "<combo>=<action>".
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard let split = value.firstIndex(of: "=") else { continue }

            let combo = value[..<split].trimmingCharacters(in: .whitespaces)
            let action = value[value.index(after: split)...].trimmingCharacters(in: .whitespaces)
            guard !combo.isEmpty, !action.isEmpty else { continue }

            // Skip Ghostty's "no-op" binding values.
            let actionLower = action.lowercased()
            guard actionLower != "ignore", actionLower != "unbind" else { continue }

            shortcuts.append(
                Shortcut(
                    keys: Self.formatCombo(combo),
                    action: Self.humanize(action),
                    source: .override
                )
            )
        }

        guard !shortcuts.isEmpty else { return nil }
        return Section(title: "Custom (from config)", shortcuts: shortcuts)
    }

    /// Format a Ghostty combo. Chords are segments joined by '>' (e.g.
    /// "ctrl+a>n"); each segment is a '+'-joined combo. Single combos format
    /// directly; chords join formatted segments with " then ".
    static func formatCombo(_ combo: String) -> String {
        let segments = combo.split(separator: ">").map(String.init)
        if segments.count <= 1 {
            return KeyFormatting.chord(fromCombo: combo)
        }
        return segments
            .map { KeyFormatting.chord(fromCombo: $0) }
            .joined(separator: " then ")
    }

    /// snake_case action → "Sentence case" (e.g. new_tab → "New tab").
    static func humanize(_ action: String) -> String {
        let words = action.split(separator: "_").map(String.init).filter { !$0.isEmpty }
        guard let first = words.first else { return action }
        let rest = words.dropFirst().map { $0.lowercased() }
        return ([first.prefix(1).uppercased() + first.dropFirst().lowercased()] + rest)
            .joined(separator: " ")
    }

    // MARK: - Built-in sections (curated macOS defaults)

    static let builtInSections: [Section] = [
        Section(title: "Tabs & Splits", shortcuts: [
            Shortcut(keys: "⌘T", action: "New tab", essential: true),
            Shortcut(keys: "⌘W", action: "Close surface"),
            Shortcut(keys: "⌘⇧[", action: "Previous tab"),
            Shortcut(keys: "⌘⇧]", action: "Next tab"),
            Shortcut(keys: "⌘1–9", action: "Go to tab N"),
            Shortcut(keys: "⌘D", action: "Split right", essential: true),
            Shortcut(keys: "⌘⇧D", action: "Split down"),
            Shortcut(keys: "⌘⌥↑↓←→", action: "Focus split", essential: true),
            Shortcut(keys: "⌘[ / ⌘]", action: "Previous/next split"),
        ]),
        Section(title: "Font & View", shortcuts: [
            Shortcut(keys: "⌘+", action: "Increase font"),
            Shortcut(keys: "⌘-", action: "Decrease font"),
            Shortcut(keys: "⌘0", action: "Reset font"),
            Shortcut(keys: "⌘⏎", action: "Toggle fullscreen"),
            Shortcut(keys: "⌘K", action: "Clear screen"),
        ]),
        Section(title: "Window", shortcuts: [
            Shortcut(keys: "⌘N", action: "New window"),
            Shortcut(keys: "⌘⇧W", action: "Close window"),
            Shortcut(keys: "⌘,", action: "Open config"),
            Shortcut(keys: "⌘⇧,", action: "Reload config", essential: true),
        ]),
        Section(title: "Clipboard & Select", shortcuts: [
            Shortcut(keys: "⌘C", action: "Copy"),
            Shortcut(keys: "⌘V", action: "Paste"),
            Shortcut(keys: "⌘A", action: "Select all"),
            Shortcut(keys: "⌘F", action: "Search"),
        ]),
    ]
}
