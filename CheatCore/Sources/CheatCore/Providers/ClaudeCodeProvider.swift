import Foundation

/// Shortcuts for the Claude Code CLI: curated built-in defaults plus any
/// overrides parsed from ~/.claude/keybindings.json.
///
/// A tool's default keymap is not stored in its config; the config only holds
/// overrides. So we ship a curated default table and merge overrides on top.
public struct ClaudeCodeProvider: ShortcutProvider {
    public init() {}

    public let id = "claude-code"
    public let displayName = "Claude Code"
    public let symbol = "sparkles"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = true
    public var defaultConfigPath: URL? { homePath(".claude/keybindings.json") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        var sections = Self.builtInSections

        if let overrides = try loadOverrides(configPath: configPath), !overrides.isEmpty {
            sections = Self.merge(defaults: sections, overrides: overrides)
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Override parsing

    /// One parsed override: an action label mapped to a key chord.
    private struct Override {
        let action: String
        let keys: String
    }

    /// Parse keybindings.json into a list of overrides. Returns nil when the
    /// config file is missing (defaults still stand). Best-effort and defensive:
    /// anything it cannot confidently map is skipped, never thrown.
    private func loadOverrides(configPath: URL?) throws -> [Override]? {
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

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: raw)
        } catch {
            // Malformed config should not crash the sheet; keep defaults only.
            return nil
        }

        // Accept a few plausible shapes:
        //   { "keybindings": { "action": "key", ... } }
        //   { "bindings":    { "action": "key", ... } }
        //   { "action": "key", ... }                       (flat object)
        //   [ { "action": "...", "key|keys|combo": "..." }, ... ]  (array of objects)
        var overrides: [Override] = []

        if let root = object as? [String: Any] {
            let table = (root["keybindings"] as? [String: Any])
                ?? (root["bindings"] as? [String: Any])
                ?? root
            for (action, value) in table {
                guard let keys = Self.keyString(from: value), !keys.isEmpty else { continue }
                let label = action.trimmingCharacters(in: .whitespaces)
                guard !label.isEmpty else { continue }
                overrides.append(Override(action: label, keys: keys))
            }
        } else if let array = object as? [[String: Any]] {
            for entry in array {
                guard
                    let action = (entry["action"] as? String ?? entry["command"] as? String)?
                        .trimmingCharacters(in: .whitespaces),
                    !action.isEmpty
                else { continue }
                let value = entry["keys"] ?? entry["key"] ?? entry["combo"] ?? entry["chord"]
                guard let keys = Self.keyString(from: value as Any), !keys.isEmpty else { continue }
                overrides.append(Override(action: action, keys: keys))
            }
        }

        return overrides.isEmpty ? nil : overrides
    }

    /// Coerce a JSON value into a displayable key chord, or nil if unusable.
    private static func keyString(from value: Any) -> String? {
        if let s = value as? String {
            let combo = s.trimmingCharacters(in: .whitespaces)
            return combo.isEmpty ? nil : KeyFormatting.chord(fromCombo: combo)
        }
        if let tokens = value as? [String] {
            let clean = tokens.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return clean.isEmpty ? nil : KeyFormatting.chord(clean)
        }
        return nil
    }

    // MARK: - Merge

    /// Merge overrides onto the default sections. An override whose action
    /// matches a default action replaces that default's keys and is marked
    /// `.override`. Overrides with no matching default are appended to an
    /// "Overrides" section as `.custom`.
    private static func merge(defaults: [Section], overrides: [Override]) -> [Section] {
        // Index overrides by case-insensitive action for matching.
        var byAction: [String: String] = [:]
        for o in overrides {
            byAction[o.action.lowercased()] = o.keys
        }

        var consumed: Set<String> = []
        var merged: [Section] = defaults.map { section in
            let shortcuts = section.shortcuts.map { shortcut -> Shortcut in
                let key = shortcut.action.lowercased()
                guard let newKeys = byAction[key] else { return shortcut }
                consumed.insert(key)
                return Shortcut(
                    keys: newKeys,
                    action: shortcut.action,
                    essential: shortcut.essential,
                    source: .override
                )
            }
            return Section(title: section.title, shortcuts: shortcuts)
        }

        let leftovers = overrides.filter { !consumed.contains($0.action.lowercased()) }
        if !leftovers.isEmpty {
            let custom = leftovers.map {
                Shortcut(keys: $0.keys, action: $0.action, source: .custom)
            }
            merged.append(Section(title: "Overrides", shortcuts: custom))
        }

        return merged
    }

    // MARK: - Built-in sections

    static let builtInSections: [Section] = [
        Section(title: "Prompt", shortcuts: [
            Shortcut(keys: "Enter", action: "Submit message", essential: true),
            Shortcut(keys: "⇧↵ / ⌥↵", action: "Newline in prompt"),
            Shortcut(keys: "Esc", action: "Stop / clear", essential: true),
            Shortcut(keys: "Esc Esc", action: "Edit previous / rewind", essential: true),
            Shortcut(keys: "⌃C", action: "Cancel / quit"),
            Shortcut(keys: "⌃D", action: "Exit"),
            Shortcut(keys: "⌃L", action: "Clear screen"),
            Shortcut(keys: "↑ / ↓", action: "History / move"),
            Shortcut(keys: "⌃R", action: "Reverse-search history"),
        ]),
        Section(title: "Modes & input", shortcuts: [
            Shortcut(keys: "⇧Tab", action: "Toggle auto-accept / plan mode", essential: true),
            Shortcut(keys: "@", action: "Mention a file"),
            Shortcut(keys: "/", action: "Slash commands", essential: true),
            Shortcut(keys: "!", action: "Bash mode"),
            Shortcut(keys: "#", action: "Memory / add to CLAUDE.md"),
            Shortcut(keys: "⌃V", action: "Paste image"),
        ]),
    ]
}
