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
        var mode: BindingMode = .none

        func flush() {
            guard !currentShortcuts.isEmpty else {
                currentShortcuts = []
                return
            }
            let title = currentTitle ?? (mode == .service ? "Service mode" : "Bindings")
            sections.append(Section(title: title, shortcuts: currentShortcuts))
            currentShortcuts = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Table headers switch mode.
            if line.hasPrefix("[") {
                flush()
                currentTitle = nil
                switch line {
                case "[mode.main.binding]":
                    mode = .main
                case "[mode.service.binding]":
                    mode = .service
                    currentTitle = "Service mode"
                default:
                    mode = .none
                }
                continue
            }

            guard mode != .none else { continue }

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

            // Binding line: split on first " = ".
            guard let range = line.range(of: " = ") else { continue }
            let combo = String(line[line.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            guard !combo.isEmpty else { continue }

            let action = parseActionValue(rawValue)
            let keys = KeyFormatting.chord(fromCombo: combo)
            let label = humanizeAction(action)
            let essential = label.hasPrefix("Workspace:") || label.hasPrefix("Focus ")
            currentShortcuts.append(Shortcut(keys: keys, action: label, essential: essential, source: .custom))
        }
        flush()

        return ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: sections)
    }

    // MARK: - Parsing helpers

    private enum BindingMode { case none, main, service }

    /// Strip leading `#` and whitespace. Keep the text as-is otherwise (a tidy
    /// title like "Workspaces: mnemonic letters").
    private func cleanCommentTitle(_ line: String) -> String {
        var s = Substring(line)
        while s.first == "#" { s = s.dropFirst() }
        return String(s).trimmingCharacters(in: .whitespaces)
    }

    /// Turn a TOML value into a plain action string. Arrays join with " + ";
    /// surrounding quotes stripped from each element.
    private func parseActionValue(_ raw: String) -> String {
        if raw.hasPrefix("[") && raw.hasSuffix("]") {
            let inner = String(raw.dropFirst().dropLast())
            let elements = splitArrayElements(inner)
            return elements
                .map { stripQuotes($0.trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
                .joined(separator: " + ")
        }
        return stripQuotes(raw)
    }

    /// Split a TOML array body on commas that are not inside quotes.
    private func splitArrayElements(_ inner: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character? = nil
        for ch in inner {
            if let q = quote {
                if ch == q { quote = nil }
                current.append(ch)
            } else if ch == "'" || ch == "\"" {
                quote = ch
                current.append(ch)
            } else if ch == "," {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(current)
        }
        return result
    }

    private func stripQuotes(_ s: String) -> String {
        var t = s
        if (t.hasPrefix("'") && t.hasSuffix("'")) || (t.hasPrefix("\"") && t.hasSuffix("\"")),
            t.count >= 2 {
            t = String(t.dropFirst().dropLast())
        }
        return t
    }

    /// Convert a raw aerospace action into a readable, sentence-case label.
    private func humanizeAction(_ value: String) -> String {
        let v = value.trimmingCharacters(in: .whitespaces)

        if v.hasPrefix("workspace ") {
            let name = String(v.dropFirst("workspace ".count)).trimmingCharacters(in: .whitespaces)
            return "Workspace: \(name)"
        }
        if v.hasPrefix("move-node-to-workspace ") {
            var rest = String(v.dropFirst("move-node-to-workspace ".count))
            let follow = rest.contains("--focus-follows-window")
            rest = rest.replacingOccurrences(of: "--focus-follows-window", with: "")
            let name = rest.trimmingCharacters(in: .whitespaces)
            return follow ? "Move window → \(name) (follow)" : "Move window → \(name)"
        }
        if v.hasPrefix("focus ") {
            let dir = String(v.dropFirst("focus ".count)).trimmingCharacters(in: .whitespaces)
            return "Focus \(dir)"
        }
        if v.hasPrefix("move ") {
            let dir = String(v.dropFirst("move ".count)).trimmingCharacters(in: .whitespaces)
            return "Move \(dir)"
        }
        if v == "fullscreen" { return "Fullscreen" }
        if v == "layout floating tiling" { return "Toggle float/tile" }
        if v == "workspace-back-and-forth" { return "Back-and-forth workspace" }
        if v == "mode service" { return "Enter service mode" }
        if v == "mode main" { return "Return to main mode" }
        if v == "reload-config" { return "Reload config" }
        if v == "flatten-workspace-tree" { return "Flatten tree" }
        if v == "balance-sizes" { return "Balance sizes" }
        if v == "close-all-windows-but-current" { return "Close others" }
        if v == "resize smart -50" { return "Shrink" }
        if v == "resize smart +50" { return "Grow" }
        if v.hasPrefix("exec-and-forget ") {
            let path = String(v.dropFirst("exec-and-forget ".count)).trimmingCharacters(in: .whitespaces)
            let last = path.split(separator: " ").first.map(String.init) ?? path
            let component = (last as NSString).lastPathComponent
            return "Run \(component.isEmpty ? last : component)"
        }

        // Composite actions (array values joined with " + "): humanize each part.
        if v.contains(" + ") {
            let parts = v.components(separatedBy: " + ").map { humanizeAction($0) }
            return parts.joined(separator: " + ")
        }

        return v
    }
}
