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
}
