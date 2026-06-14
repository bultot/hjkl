import Foundation

/// Shortcuts for zsh: curated line-editing/readline keys, the owner's tool
/// setup, plus custom functions and aliases parsed from the live config.
public struct ZshProvider: ShortcutProvider {
    public init() {}

    public let id = "zsh"
    public let displayName = "zsh"
    public let symbol = "chevron.left.forwardslash.chevron.right"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = false
    public let executableNames = ["zsh"]
    public var defaultConfigPath: URL? { homePath(".config/zsh/functions.zsh") }

    public func load(configPath: URL?) throws -> ShortcutSheet {
        var sections = Self.builtInSections

        let custom = loadCustom(configPath: configPath)
        if !custom.shortcuts.isEmpty {
            sections.append(custom)
        }

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Custom functions & aliases

    /// Parse functions from functions.zsh and aliases from a sibling aliases.zsh
    /// into a single "Custom (functions & aliases)" section. Missing files yield
    /// no shortcuts (the curated defaults still stand). Never throws.
    private func loadCustom(configPath: URL?) -> Section {
        var shortcuts: [Shortcut] = []

        let functionsURL: URL?
        do {
            functionsURL = try resolvedPath(configPath)
        } catch {
            functionsURL = nil
        }

        if let functionsURL, let text = try? String(contentsOf: functionsURL, encoding: .utf8) {
            shortcuts.append(contentsOf: Self.parseFunctions(text))

            let aliasesURL = functionsURL
                .deletingLastPathComponent()
                .appendingPathComponent("aliases.zsh")
            if let aliasText = try? String(contentsOf: aliasesURL, encoding: .utf8) {
                shortcuts.append(contentsOf: Self.parseAliases(aliasText))
            }
        }

        return Section(title: "Custom (functions & aliases)", shortcuts: shortcuts)
    }

    /// Find `name() {`, `function name {`, or `function name()` definitions and
    /// use the contiguous `#` comment line(s) directly above as the description.
    static func parseFunctions(_ text: String) -> [Shortcut] {
        let lines = text.components(separatedBy: "\n")
        var shortcuts: [Shortcut] = []

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let name = functionName(from: line) else { continue }

            // Walk upward collecting the leading comment block; first line wins.
            var description = name
            var i = index - 1
            while i >= 0 {
                let prev = lines[i].trimmingCharacters(in: .whitespaces)
                if prev.hasPrefix("#") {
                    let cleaned = prev.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        description = cleaned
                    }
                    i -= 1
                } else {
                    break
                }
            }

            shortcuts.append(Shortcut(keys: name, action: description, source: .custom))
        }

        return shortcuts
    }

    /// Extract a function name from a definition line, or nil if not a definition.
    /// Handles `name() {`, `name()` (brace on next line), `function name {`,
    /// `function name()`, and `function name`.
    private static func functionName(from line: String) -> String? {
        if line.hasPrefix("function ") {
            var rest = line.dropFirst("function ".count).trimmingCharacters(in: .whitespaces)
            if let parenIndex = rest.firstIndex(of: "(") {
                rest = String(rest[rest.startIndex..<parenIndex])
            } else if let braceIndex = rest.firstIndex(of: "{") {
                rest = String(rest[rest.startIndex..<braceIndex])
            }
            let name = rest.trimmingCharacters(in: .whitespaces)
            return isValidName(name) ? name : nil
        }

        // `name() {` or `name ()`
        guard let parenIndex = line.firstIndex(of: "(") else { return nil }
        let name = String(line[line.startIndex..<parenIndex]).trimmingCharacters(in: .whitespaces)
        let after = line[line.index(after: parenIndex)...].trimmingCharacters(in: .whitespaces)
        // Require the form `name(` immediately followed by `)` (an empty arg list).
        guard after.hasPrefix(")") else { return nil }
        return isValidName(name) ? name : nil
    }

    private static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    /// Parse `alias name='...'` or `alias name="..."` into shortcuts whose
    /// action is the (unquoted) alias target.
    static func parseAliases(_ text: String) -> [Shortcut] {
        var shortcuts: [Shortcut] = []

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("alias ") else { continue }

            let body = line.dropFirst("alias ".count).trimmingCharacters(in: .whitespaces)
            guard let eq = body.firstIndex(of: "=") else { continue }

            let name = String(body[body.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            guard isValidName(name) else { continue }

            var value = String(body[body.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2) ||
               (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2) {
                value = String(value.dropFirst().dropLast())
            }
            guard !value.isEmpty else { continue }

            shortcuts.append(Shortcut(keys: name, action: value, source: .custom))
        }

        return shortcuts
    }

    // MARK: - Curated defaults

    static let builtInSections: [Section] = [
        Section(title: "Line editing", shortcuts: [
            Shortcut(keys: "⌃A", action: "Beginning of line", essential: true),
            Shortcut(keys: "⌃E", action: "End of line", essential: true),
            Shortcut(keys: "⌃W", action: "Delete word back"),
            Shortcut(keys: "⌥←/⌥→", action: "Word back/forward"),
            Shortcut(keys: "⌃U", action: "Clear line"),
            Shortcut(keys: "⌃K", action: "Kill to end"),
            Shortcut(keys: "⌃R", action: "History search", essential: true),
            Shortcut(keys: "⌃L", action: "Clear screen"),
            Shortcut(keys: "⌃C", action: "Cancel"),
            Shortcut(keys: "⌃D", action: "EOF/exit"),
            Shortcut(keys: "⌃Z", action: "Suspend"),
            Shortcut(keys: "!!", action: "Repeat last command"),
            Shortcut(keys: "!$", action: "Last arg"),
        ]),
        Section(title: "Tools", shortcuts: [
            Shortcut(keys: "z <dir>", action: "zoxide jump", essential: true),
            Shortcut(keys: "fzf ⌃T", action: "Fuzzy file"),
            Shortcut(keys: "fzf ⌃R", action: "Fuzzy history"),
            Shortcut(keys: "sesh / prefix o", action: "Session switcher"),
            Shortcut(keys: "eza / ls", action: "Listing"),
            Shortcut(keys: "bat", action: "cat with syntax"),
            Shortcut(keys: "yazi", action: "File manager"),
        ]),
    ]
}
