import AppKit
import CheatCore

/// Watches which app is frontmost and updates the model's selected tab so the
/// overlay defaults to the app you're in.
@MainActor
final class ContextMonitor {
    private let model: AppModel
    private var token: (any NSObjectProtocol)?

    init(model: AppModel) { self.model = model }

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [model] note in
            let bid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in model.selectForFrontmost(bundleID: bid) }
        }
    }

    func stop() {
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        token = nil
    }
}
