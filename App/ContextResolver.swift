import Foundation
import CheatCore

/// Resolves the provider for the current terminal context by shelling out to the
/// cmux CLI. Only acts when the frontmost app is cmux; otherwise returns nil so
/// the caller falls back to bundle-id matching.
struct ContextResolver {
    static let cmuxBundleID = "com.cmuxterm.app"

    /// Provider id for the tool in the foreground of cmux's active pane, or nil.
    func providerID(forFrontmostBundle bundle: String?) -> String? {
        guard bundle == Self.cmuxBundleID, let data = runCmuxTop() else { return nil }
        return TerminalContext.providerID(fromCmuxTopJSON: data)
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
