import AppKit
import SwiftUI

/// Floating panel that hosts the cheat sheet. Can become key (for toggle-mode
/// interaction) but never activates as the main app window.
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 640),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows/hides the overlay and routes context to the model before each show.
@MainActor
final class OverlayController {
    private let panel: OverlayPanel
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        self.panel = OverlayPanel()
        let hosting = NSHostingView(
            rootView: CheatSheetView(model: model) { [weak panel] in panel?.orderOut(nil) }
        )
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    var isVisible: Bool { panel.isVisible }

    /// Toggle for the sticky hotkey (interactive: becomes key).
    func toggle() {
        if panel.isVisible { hide() } else { show(activating: true) }
    }

    /// `activating: true` → interactive (vim nav, filter). `false` → glance only
    /// (hold-to-peek), shown without stealing focus.
    func show(activating: Bool) {
        model.selectForFrontmost(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        centerOnActiveScreen()
        if activating {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func centerOnActiveScreen() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let f = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - f.width / 2,
            y: visible.midY - f.height / 2
        ))
    }
}
