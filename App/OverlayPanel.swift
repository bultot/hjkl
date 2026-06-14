import AppKit
import SwiftUI

/// Floating panel that hosts the cheat sheet. Can become key (for toggle-mode
/// interaction) but never activates as the main app window.
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: CheatSheetView.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        // The card draws its own soft shadow in SwiftUI (see CheatSheetView);
        // the AppKit window shadow would clip to the transparent window bounds.
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        // No window-level show/hide animation — the overlay must appear and
        // disappear instantly.
        animationBehavior = .none
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
            rootView: CheatSheetView(model: model) { [weak self] in self?.hide() }
        )
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    /// App that was frontmost before we activated, so we can hand focus back on hide.
    private var previousApp: NSRunningApplication?

    var isVisible: Bool { panel.isVisible }

    /// Toggle for the sticky hotkey (interactive: becomes key).
    func toggle() {
        if isVisible { hide() } else { show(activating: true) }
    }

    /// `activating: true` → interactive (vim nav, filter). `false` → glance only
    /// (hold-to-peek), shown without stealing focus. Appears and dismisses
    /// instantly — no transitions.
    func show(activating: Bool) {
        // Match the panel's appearance to the theme so AppKit-backed controls
        // (e.g. the search field's editor) draw readable text. System theme
        // follows the OS (nil appearance).
        panel.appearance = model.theme.usesSystemMaterials
            ? nil
            : NSAppearance(named: model.theme.isDark ? .darkAqua : .aqua)

        let front = NSWorkspace.shared.frontmostApplication
        let bundle = front?.bundleIdentifier
        // Cheap, synchronous tab pick from the frontmost app's bundle id so the
        // panel is correct for the common case the instant it appears.
        model.selectForFrontmost(bundleID: bundle)

        panel.alphaValue = 1
        panel.setFrame(defaultFrame(), display: false)

        if activating {
            // Remember who to hand focus back to (ignore ourselves on re-toggle).
            if bundle != Bundle.main.bundleIdentifier {
                previousApp = front
            }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }

        // Process-aware refinement shells out to a terminal CLI (cmux's pane probe
        // or `tmux list-clients`), so do it off the main thread and switch tabs when
        // it returns — the panel never waits on a subprocess. The resolver returns
        // nil for non-terminal apps, so the detached probe is cheap there.
        let resolver = self.resolver
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let pid = resolver.providerID(forFrontmostBundle: bundle) else { return }
            await self?.applyResolvedProvider(pid)
        }
    }

    /// Switch to the process-aware provider once the async cmux probe returns.
    private func applyResolvedProvider(_ pid: String) {
        guard panel.isVisible, model.hasSheet(pid) else { return }
        model.select(providerID: pid)
    }

    func hide() {
        guard panel.isVisible else { return }
        // Instant dismiss — no fade or slide.
        panel.orderOut(nil)
        // Hand focus back to whoever had it before we activated.
        previousApp?.activate()
        previousApp = nil
    }

    /// Horizontally centered; vertically biased toward the upper third to match
    /// Raycast's default placement (window center ~40% from the top of the
    /// screen, i.e. above true center). The window includes the shadow margin
    /// symmetrically, so its center coincides with the card's center.
    private func defaultFrame() -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        // AppKit y grows upward: 0.60 of the height up from the bottom puts the
        // center at 40% from the top.
        let centerY = visible.minY + visible.height * 0.60
        return NSRect(
            x: visible.midX - size.width / 2,
            y: centerY - size.height / 2,
            width: size.width, height: size.height
        )
    }
}
