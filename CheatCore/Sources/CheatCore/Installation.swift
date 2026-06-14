import Foundation

/// Detects whether a tool is actually present on the machine, so the app only
/// shows a provider's tab when its tool exists. Pure Foundation, no AppKit.
///
/// A GUI-launched app inherits a minimal PATH (often just `/usr/bin:/bin:...`),
/// not the user's interactive shell PATH, so we search a fixed set of common
/// install locations in addition to whatever PATH we were handed.
public enum Installation {
    /// Directories to look in for a CLI binary, beyond the inherited PATH.
    private static var searchDirs: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let fromPath = path.split(separator: ":").map(String.init)
        let common = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin",
            "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin",
            "\(home)/.local/bin", "\(home)/bin", "\(home)/.cargo/bin",
        ]
        // Preserve order, drop duplicates.
        var seen = Set<String>()
        return (fromPath + common).filter { seen.insert($0).inserted }
    }

    /// True when any of the named executables is found on PATH or in a common dir.
    public static func hasExecutable(_ names: [String]) -> Bool {
        guard !names.isEmpty else { return false }
        let fm = FileManager.default
        for dir in searchDirs {
            for name in names where fm.isExecutableFile(atPath: dir + "/" + name) {
                return true
            }
        }
        return false
    }

    /// True when any of the named `.app` bundles exists in /Applications or ~/Applications.
    public static func hasApp(_ appNames: [String]) -> Bool {
        guard !appNames.isEmpty else { return false }
        let fm = FileManager.default
        let roots = ["/Applications", fm.homeDirectoryForCurrentUser.appending(path: "Applications").path]
        for root in roots {
            for name in appNames where fm.fileExists(atPath: "\(root)/\(name).app") {
                return true
            }
        }
        return false
    }
}
