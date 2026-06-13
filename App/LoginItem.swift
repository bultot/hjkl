import ServiceManagement

/// Launch-at-login for the main app, backed by SMAppService (macOS 13+). The app
/// is LSUIElement, so it starts straight into the menu bar with no Dock icon or
/// window.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Register/unregister the login item. Returns the resulting state so the UI
    /// can stay in sync even when the system rejects the change (e.g. pending
    /// user approval in System Settings → General → Login Items).
    @discardableResult
    static func setEnabled(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("hjkl: login item \(on ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
