import Foundation
import CheatCore

/// Resolves the provider for the current terminal context by shelling out to a
/// terminal CLI. Acts when the frontmost app is cmux (pane-aware probe) or a known
/// terminal hosting an attached tmux client; otherwise returns nil so the caller
/// falls back to bundle-id matching.
struct ContextResolver: Sendable {
    static let cmuxBundleID = "com.cmuxterm.app"

    /// Provider id for the current terminal context, or nil. cmux keeps its
    /// pane-aware precedence; otherwise a known terminal with an attached tmux
    /// client resolves to "tmux".
    func providerID(forFrontmostBundle bundle: String?) -> String? {
        if bundle == Self.cmuxBundleID {
            guard let data = runCmuxTop() else { return nil }
            return TerminalContext.providerID(fromCmuxTopJSON: data)
        }
        // Only shell out for known terminals; the pure function makes the final call.
        guard let bundle, TerminalContext.knownTerminalBundleIDs.contains(bundle) else { return nil }
        return TerminalContext.terminalProviderID(
            frontmostBundleID: bundle,
            tmuxAttached: tmuxClientAttached()
        )
    }

    /// Coarse detection: a tmux client is attached *anywhere* if `tmux list-clients`
    /// exits 0 with non-empty output. Accepts the known false positive of tmux
    /// running in a different window than the frontmost terminal.
    private func tmuxClientAttached() -> Bool {
        guard let cli = tmuxCLIPath() else { return false }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cli)
        proc.arguments = ["list-clients"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return false }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return proc.terminationStatus == 0 && !data.isEmpty
    }

    private func tmuxCLIPath() -> String? {
        let fm = FileManager.default
        for candidate in [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ] where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    private func cmuxCLIPath() -> String? {
        let fm = FileManager.default
        if let p = ProcessInfo.processInfo.environment["CMUX_BUNDLED_CLI_PATH"],
           fm.isExecutableFile(atPath: p) { return p }
        for candidate in [
            "/Applications/cmux.app/Contents/Resources/bin/cmux",
            "/opt/homebrew/bin/cmux",
            "/usr/local/bin/cmux",
        ] where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    private func runCmuxTop() -> Data? {
        guard let cli = cmuxCLIPath() else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cli)
        proc.arguments = ["top", "--json", "--processes"]
        var env = ProcessInfo.processInfo.environment
        env["CMUX_QUIET"] = "1"
        proc.environment = env
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return data.isEmpty ? nil : data
    }
}
