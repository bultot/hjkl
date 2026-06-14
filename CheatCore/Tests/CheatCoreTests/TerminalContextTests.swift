import Testing
import Foundation
@testable import CheatCore

@Suite("TerminalContext")
struct TerminalContextTests {
    /// Build a minimal cmux-top-shaped JSON with one active surface whose
    /// foreground process group runs `path`.
    func json(activeRef: String, fgPgid: Int, procPath: String, procPgid: Int) -> Data {
        let obj: [String: Any] = [
            "active": ["surface_ref": activeRef],
            "tree": [
                "kind": "window",
                "children": [
                    [
                        "kind": "surface", "ref": activeRef, "focused": true,
                        "foreground_pgids": [fgPgid],
                        "processes": [
                            ["kind": "process", "pid": 100, "pgid": procPgid, "path": procPath,
                             "children": [
                                ["kind": "process", "pid": 101, "pgid": procPgid, "path": "/opt/homebrew/bin/node"]
                             ]],
                        ],
                    ]
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: obj)
    }

    @Test("claude foreground → claude-code")
    func claude() {
        let d = json(activeRef: "surface:1", fgPgid: 5, procPath: "/Users/x/.local/share/claude/versions/2.1.177", procPgid: 5)
        #expect(TerminalContext.providerID(fromCmuxTopJSON: d) == "claude-code")
    }

    @Test("lazygit foreground → lazygit")
    func lazygit() {
        let d = json(activeRef: "surface:2", fgPgid: 7, procPath: "/opt/homebrew/bin/lazygit", procPgid: 7)
        #expect(TerminalContext.providerID(fromCmuxTopJSON: d) == "lazygit")
    }

    @Test("nvim foreground → neovim")
    func nvim() {
        let d = json(activeRef: "surface:3", fgPgid: 9, procPath: "/opt/homebrew/bin/nvim", procPgid: 9)
        #expect(TerminalContext.providerID(fromCmuxTopJSON: d) == "neovim")
    }

    @Test("plain shell → zsh")
    func shell() {
        let d = json(activeRef: "surface:4", fgPgid: 11, procPath: "/bin/zsh", procPgid: 11)
        #expect(TerminalContext.providerID(fromCmuxTopJSON: d) == "zsh")
    }

    @Test("classify ignores node noise, picks the tool")
    func classifyOrder() {
        #expect(TerminalContext.classify(["/opt/homebrew/bin/node", "/opt/homebrew/bin/lazygit"]) == "lazygit")
        #expect(TerminalContext.classify(["/bin/zsh"]) == "zsh")
        #expect(TerminalContext.classify(["/usr/bin/caffeinate"]) == nil)
    }

    // MARK: - tmux client detection

    @Test("known terminal + tmux attached → tmux", arguments: [
        "com.mitchellh.ghostty",   // Ghostty
        "com.googlecode.iterm2",   // iTerm2
        "com.apple.Terminal",      // Terminal.app
        "org.alacritty",           // Alacritty
        "net.kovidgoyal.kitty",    // kitty
        "com.github.wez.wezterm",  // WezTerm
    ])
    func tmuxInKnownTerminal(bundle: String) {
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: bundle, tmuxAttached: true) == "tmux")
    }

    @Test("known terminal but no tmux client → nil")
    func terminalWithoutTmux() {
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: "com.mitchellh.ghostty", tmuxAttached: false) == nil)
    }

    @Test("non-terminal app → nil regardless of tmux")
    func nonTerminal() {
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: "com.apple.Safari", tmuxAttached: true) == nil)
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: "com.apple.Safari", tmuxAttached: false) == nil)
    }

    @Test("cmux bundle → nil so the cmux probe keeps precedence")
    func cmuxKeepsPrecedence() {
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: "com.cmuxterm.app", tmuxAttached: true) == nil)
    }

    @Test("nil bundle → nil")
    func nilBundle() {
        #expect(TerminalContext.terminalProviderID(frontmostBundleID: nil, tmuxAttached: true) == nil)
    }
}
