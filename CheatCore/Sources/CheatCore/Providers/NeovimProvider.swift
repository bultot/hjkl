import Foundation

/// Shortcuts for Neovim: a curated table of the built-in default motions and
/// commands.
///
/// Neovim's defaults live in the editor itself, not in `~/.config/nvim`. The
/// config holds only user keymaps (arbitrary Lua), which we deliberately do not
/// parse. So this provider ships a curated default cheat sheet and always
/// returns it, whether or not a config directory is present.
public struct NeovimProvider: ShortcutProvider {
    public init() {}

    public let id = "neovim"
    public let displayName = "Neovim"
    public let symbol = "doc.text"
    public let matchBundleIDs: [String] = []
    public let alwaysAvailable = true
    public var defaultConfigPath: URL? { homePath(".config/nvim") }

    /// Always returns the curated defaults. A missing config directory is not an
    /// error here: the defaults are the value. Parsing arbitrary Lua keymaps is
    /// out of scope.
    public func load(configPath: URL?) throws -> ShortcutSheet {
        ShortcutSheet(id: id, title: displayName, symbol: symbol, sections: Self.builtInSections)
    }

    // MARK: - Built-in sections

    static let builtInSections: [Section] = [
        Section(title: "Motions", shortcuts: [
            Shortcut(keys: "h j k l", action: "Left/down/up/right", essential: true),
            Shortcut(keys: "w / b", action: "Word fwd/back", essential: true),
            Shortcut(keys: "e / ge", action: "End of word"),
            Shortcut(keys: "0 / ^ / $", action: "Line start/first/end", essential: true),
            Shortcut(keys: "gg / G", action: "File top/bottom", essential: true),
            Shortcut(keys: "{ / }", action: "Paragraph"),
            Shortcut(keys: "%", action: "Matching pair"),
            Shortcut(keys: "f/F/t/T x", action: "Find char on line"),
            Shortcut(keys: "Ctrl-d / Ctrl-u", action: "Half-page down/up"),
        ]),
        Section(title: "Editing", shortcuts: [
            Shortcut(keys: "i / a", action: "Insert before/after", essential: true),
            Shortcut(keys: "I / A", action: "Insert line start/end"),
            Shortcut(keys: "o / O", action: "Open line below/above"),
            Shortcut(keys: "x / X", action: "Delete char"),
            Shortcut(keys: "dd", action: "Delete line", essential: true),
            Shortcut(keys: "yy", action: "Yank line", essential: true),
            Shortcut(keys: "p / P", action: "Paste after/before", essential: true),
            Shortcut(keys: "r / R", action: "Replace"),
            Shortcut(keys: "cc / C", action: "Change line/to end"),
            Shortcut(keys: "u / Ctrl-r", action: "Undo / redo", essential: true),
            Shortcut(keys: ".", action: "Repeat last change", essential: true),
            Shortcut(keys: ">> / <<", action: "Indent / dedent"),
        ]),
        Section(title: "Operators + text objects", shortcuts: [
            Shortcut(keys: "ciw / diw", action: "Change/delete inner word", essential: true),
            Shortcut(keys: "ci\" / di(", action: "Inside quotes/parens"),
            Shortcut(keys: "dap / dip", action: "Around/inner paragraph"),
            Shortcut(keys: "ggVG", action: "Select all"),
        ]),
        Section(title: "Search & replace", shortcuts: [
            Shortcut(keys: "/ pattern", action: "Search fwd", essential: true),
            Shortcut(keys: "? pattern", action: "Search back"),
            Shortcut(keys: "n / N", action: "Next/prev match"),
            Shortcut(keys: "* / #", action: "Search word under cursor"),
            Shortcut(keys: ":%s/a/b/g", action: "Replace all", essential: true),
            Shortcut(keys: ":noh", action: "Clear highlight"),
        ]),
        Section(title: "Files, windows, tabs", shortcuts: [
            Shortcut(keys: ":w / :q / :wq", action: "Write/quit", essential: true),
            Shortcut(keys: ":qa!", action: "Quit all force"),
            Shortcut(keys: "Ctrl-w s / v", action: "Split horiz/vert"),
            Shortcut(keys: "Ctrl-w h j k l", action: "Move between splits", essential: true),
            Shortcut(keys: "gt / gT", action: "Next/prev tab"),
            Shortcut(keys: ":e file", action: "Open file"),
        ]),
        Section(title: "Visual mode", shortcuts: [
            Shortcut(keys: "v / V / Ctrl-v", action: "Char/line/block select", essential: true),
            Shortcut(keys: "> / <", action: "Indent selection"),
            Shortcut(keys: "y / d", action: "Yank/delete selection"),
            Shortcut(keys: "gv", action: "Reselect"),
        ]),
    ]
}
