import Foundation

/// Resolves which provider a terminal pane is "in" from cmux's process tree.
///
/// Given the JSON of `cmux top --json --processes`, it finds the active surface,
/// looks at the foreground process group's executable paths, and maps the tool
/// running there (lazygit / nvim / claude / shell) to a provider id. Pure and
/// testable; the app layer shells out to the cmux CLI and feeds the data in.
public enum TerminalContext {

    /// Returns a provider id ("lazygit", "neovim", "claude-code", "zsh") for the
    /// tool in the foreground of cmux's active surface, or nil if undetermined
    /// (caller should fall back to the default terminal provider).
    public static func providerID(fromCmuxTopJSON data: Data) -> String? {
        guard
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let active = (root["active"] as? [String: Any])?["surface_ref"] as? String,
            let surface = findSurface(in: root, ref: active)
        else { return nil }

        let foreground = Set((surface["foreground_pgids"] as? [Int]) ?? [])
        var paths: [String] = []
        collectProcessPaths(surface["processes"], foreground: foreground, into: &paths)
        return classify(paths)
    }

    /// Bundle IDs of terminal emulators that can host a tmux client. Verified
    /// against each app's real bundle identifier. cmux is deliberately absent:
    /// it has its own process-aware probe that must keep precedence.
    public static let knownTerminalBundleIDs: Set<String> = [
        "com.mitchellh.ghostty",  // Ghostty
        "com.googlecode.iterm2",  // iTerm2
        "com.apple.Terminal",     // Terminal.app
        "org.alacritty",          // Alacritty
        "net.kovidgoyal.kitty",   // kitty
        "com.github.wez.wezterm", // WezTerm
    ]

    /// Decide whether to resolve to tmux based on the frontmost app and whether a
    /// tmux client is attached anywhere. Returns "tmux" only when a tmux client is
    /// attached AND the frontmost app is a known terminal emulator; nil otherwise
    /// (caller then falls back to bundle-id matching / the cmux probe). cmux is
    /// excluded so its pane-aware probe keeps precedence.
    ///
    /// Detection is coarse: `tmuxAttached` means a client is attached somewhere,
    /// not necessarily in the frontmost window. The accepted false positive is a
    /// non-tmux terminal being frontmost while tmux runs in another window.
    public static func terminalProviderID(frontmostBundleID: String?, tmuxAttached: Bool) -> String? {
        guard tmuxAttached, let bundle = frontmostBundleID,
              knownTerminalBundleIDs.contains(bundle) else { return nil }
        return "tmux"
    }

    /// Map a set of foreground executable paths to a provider id. Order matters:
    /// check specific tools before the generic shell.
    static func classify(_ paths: [String]) -> String? {
        let lower = paths.map { $0.lowercased() }
        func has(_ needles: [String]) -> Bool {
            lower.contains { p in needles.contains { p.contains($0) } }
        }
        if has(["/lazygit", "/gitui"]) { return "lazygit" }
        if has(["/nvim"]) { return "neovim" }
        if has(["/vim"]) { return "neovim" }
        if has(["/claude", "claude/versions"]) { return "claude-code" }
        if lower.contains(where: isShell) { return "zsh" }
        return nil
    }

    private static func isShell(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        return ["zsh", "-zsh", "bash", "-bash", "sh", "fish"].contains(name)
    }

    // MARK: - JSON walking

    private static func findSurface(in node: Any, ref: String) -> [String: Any]? {
        if let dict = node as? [String: Any] {
            if dict["kind"] as? String == "surface", dict["ref"] as? String == ref {
                return dict
            }
            for value in dict.values {
                if let found = findSurface(in: value, ref: ref) { return found }
            }
        } else if let arr = node as? [Any] {
            for value in arr {
                if let found = findSurface(in: value, ref: ref) { return found }
            }
        }
        return nil
    }

    /// Collect executable paths of foreground processes under `node`. When
    /// `foreground` is empty (no pgid info), include every process as a fallback.
    private static func collectProcessPaths(_ node: Any?, foreground: Set<Int>, into paths: inout [String]) {
        guard let node else { return }
        if let dict = node as? [String: Any] {
            if dict["kind"] as? String == "process", let path = dict["path"] as? String {
                let pgid = dict["pgid"] as? Int
                if foreground.isEmpty || (pgid != nil && foreground.contains(pgid!)) {
                    paths.append(path)
                }
            }
            for value in dict.values {
                collectProcessPaths(value, foreground: foreground, into: &paths)
            }
        } else if let arr = node as? [Any] {
            for value in arr {
                collectProcessPaths(value, foreground: foreground, into: &paths)
            }
        }
    }
}
