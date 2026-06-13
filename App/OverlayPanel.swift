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
    private let resolver = ContextResolver()

    init(model: AppModel) {
        self.model = model
        self.panel = OverlayPanel()
        let hosting = NSHostingView(
            rootView: CheatSheetView(model: model) { [weak panel] in panel?.orderOut(nil) }
        )
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    private var isAnimatingOut = false

    var isVisible: Bool { panel.isVisible && !isAnimatingOut }

    /// Toggle for the sticky hotkey (interactive: becomes key).
    func toggle() {
        if isVisible { hide() } else { show(activating: true) }
    }

    /// `activating: true` → interactive (vim nav, filter). `false` → glance only
    /// (hold-to-peek), shown without stealing focus. Animates in with a quick
    /// fade + subtle rise (skipped under Reduce Motion).
    func show(activating: Bool) {
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        // Process-aware: inside cmux, switch to the tool running in the focused pane.
        if let pid = resolver.providerID(forFrontmostBundle: bundle), model.hasSheet(pid) {
            model.select(providerID: pid)
        } else {
            model.selectForFrontmost(bundleID: bundle)
        }
        isAnimatingOut = false
        panel.alphaValue = 0

        let target = centeredFrame()
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(reduce ? target : target.offsetBy(dx: 0, dy: -10), display: false)

        if activating {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduce ? 0.08 : 0.13
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }

    func hide() {
        guard panel.isVisible, !isAnimatingOut else { return }
        isAnimatingOut = true
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let end = reduce ? panel.frame : panel.frame.offsetBy(dx: 0, dy: -8)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduce ? 0.06 : 0.10
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(end, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            panel.orderOut(nil)
            panel.alphaValue = 1
            isAnimatingOut = false
        })
    }

    private func centeredFrame() -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width, height: size.height
        )
    }
}
