import Foundation

/// Shortcuts for lazygit. lazygit does not write its DEFAULT keybindings into the
/// config file (only overrides are stored there), so we ship a curated table of
/// the well-known defaults as `.builtinDefault`. If a config file exists, we make
/// a tolerant, best-effort scan of the `keybinding:` block and surface any
/// overrides we can read as `.override`. lazygit keys are literal single letters
/// or simple combos (no ⌘), so we pass them through verbatim.
public struct LazygitProvider: ShortcutProvider {
    public init() {}

    public let id = "lazygit"
    public let displayName = "lazygit"
    public let symbol = "arrow.triangle.branch"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = true
    public var defaultConfigPath: URL? { homePath(".config/lazygit/config.yml") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        var sections = Self.defaultSections()

        // Best-effort override scan. Never crash on a malformed/missing file.
        if let overrides = readOverrides(configPath) {
            sections.append(overrides)
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Curated defaults

    private static func defaultSections() -> [Section] {
        [
            Section(title: "Global", shortcuts: [
                Shortcut(keys: "?", action: "Keybindings menu", essential: true),
                Shortcut(keys: "q", action: "Quit", essential: true),
                Shortcut(keys: "<pgup>/<pgdn>", action: "Scroll"),
                Shortcut(keys: "@", action: "Command log"),
                Shortcut(keys: "+ / -", action: "Next/prev screen mode"),
                Shortcut(keys: "x", action: "Open menu"),
                Shortcut(keys: ":", action: "Custom command"),
            ]),
            Section(title: "Navigation", shortcuts: [
                Shortcut(keys: "h j k l", action: "Move between panels/items", essential: true),
                Shortcut(keys: "[ ]", action: "Prev/next tab"),
                Shortcut(keys: "1–5", action: "Jump to panel"),
            ]),
            Section(title: "Files", shortcuts: [
                Shortcut(keys: "space", action: "Stage/unstage", essential: true),
                Shortcut(keys: "a", action: "Stage all"),
                Shortcut(keys: "c", action: "Commit", essential: true),
                Shortcut(keys: "A", action: "Amend"),
                Shortcut(keys: "d", action: "Discard"),
                Shortcut(keys: "e", action: "Edit"),
                Shortcut(keys: "s", action: "Stash"),
                Shortcut(keys: "<enter>", action: "Stage individual lines"),
            ]),
            Section(title: "Branches", shortcuts: [
                Shortcut(keys: "space", action: "Checkout"),
                Shortcut(keys: "n", action: "New branch"),
                Shortcut(keys: "M", action: "Merge"),
                Shortcut(keys: "r", action: "Rebase"),
                Shortcut(keys: "d", action: "Delete"),
            ]),
            Section(title: "Commits", shortcuts: [
                Shortcut(keys: "s", action: "Squash down"),
                Shortcut(keys: "r", action: "Reword"),
                Shortcut(keys: "d", action: "Drop"),
                Shortcut(keys: "p", action: "Pick"),
                Shortcut(keys: "e", action: "Edit"),
                Shortcut(keys: "<c-j>/<c-k>", action: "Move commit down/up"),
            ]),
            Section(title: "Remote", shortcuts: [
                Shortcut(keys: "p", action: "Pull", essential: true),
                Shortcut(keys: "P", action: "Push", essential: true),
                Shortcut(keys: "f", action: "Fetch"),
            ]),
        ]
    }

    // MARK: - Override parsing (best-effort)

    /// Scan the `keybinding:` block for `name: "<key>"` lines. The lazygit schema
    /// is large and nested; we cannot reliably map every key to a human action
    /// without it, so we humanize the setting name (which is descriptive, e.g.
    /// `commitChanges`) and report the configured key. Returns nil if there is
    /// nothing usable or the file cannot be read.
    private func readOverrides(_ configPath: URL?) -> Section? {
        guard let url = try? resolvedPath(configPath) else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var shortcuts: [Shortcut] = []
        var inBlock = false
        var blockIndent = 0

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inBlock {
                if trimmed.hasPrefix("keybinding:") {
                    inBlock = true
                    blockIndent = indent
                }
                continue
            }

            // A non-comment key at or below the block's indent ends the block.
            if indent <= blockIndent && !trimmed.hasPrefix("#") {
                break
            }
            if trimmed.hasPrefix("#") { continue }

            // Expect `name: value`.
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let name = String(trimmed[trimmed.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            // Strip inline comments and quotes.
            if let hash = value.firstIndex(of: "#") {
                value = String(value[value.startIndex..<hash]).trimmingCharacters(in: .whitespaces)
            }
            value = stripQuotes(value)

            // Skip nested sub-blocks (empty value) and non-scalar values.
            guard !name.isEmpty, !value.isEmpty, !value.hasPrefix("["), !value.hasPrefix("{") else { continue }

            shortcuts.append(Shortcut(keys: value, action: humanize(name), source: .override))
        }

        return shortcuts.isEmpty ? nil : Section(title: "Overrides", shortcuts: shortcuts)
    }

    private func stripQuotes(_ s: String) -> String {
        var t = s
        if t.count >= 2,
            (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
            t = String(t.dropFirst().dropLast())
        }
        return t
    }

    /// Turn a camelCase setting name into a spaced, sentence-case label.
    private func humanize(_ name: String) -> String {
        var out = ""
        for ch in name {
            if ch.isUppercase && !out.isEmpty { out.append(" ") }
            out.append(ch)
        }
        guard let first = out.first else { return out }
        return first.uppercased() + out.dropFirst().lowercased()
    }
}
