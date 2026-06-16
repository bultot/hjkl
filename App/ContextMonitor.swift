import AppKit
import CheatCore

/// Watches which app is frontmost and updates the model's selected tab so the
/// overlay defaults to the app you're in.
@MainActor
final class ContextMonitor {
    private let model: AppModel
    /// Called on each app activation so the overlay can warm its terminal-context
    /// cache ahead of time, making the next open land on the right tab instantly.
    private let onActivate: (String?) -> Void
    private var token: (any NSObjectProtocol)?

    init(model: AppModel, onActivate: @escaping (String?) -> Void = { _ in }) {
        self.model = model
        self.onActivate = onActivate
    }

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let bid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                guard let self else { return }
                self.model.selectForFrontmost(bundleID: bid)
                self.onActivate(bid)
            }
        }
    }

    func stop() {
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        token = nil
    }
}
