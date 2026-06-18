import AppKit
import SwiftUI
import CheatCore

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

    /// Last terminal-context resolution per app bundle id. Lets the overlay open
    /// directly on the right tab instead of flashing the bundle match first and
    /// switching when the (slow, subprocess-backed) probe returns.
    private var contextCache: [String: String] = [:]

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

        // Each session starts ready to type: empty query, current-app scope.
        model.resetSearch()

        let front = NSWorkspace.shared.frontmostApplication
        let bundle = front?.bundleIdentifier
        // Instant tab pick: a cached terminal-context resolution (e.g. tmux inside
        // a terminal) takes precedence so the panel opens on the right tab; else
        // fall back to the synchronous bundle match.
        if let cached = bundle.flatMap({ contextCache[$0] }), model.hasSheet(cached) {
            model.select(providerID: cached)
        } else {
            model.selectForFrontmost(bundleID: bundle)
        }

        panel.alphaValue = 1
        panel.setFrame(defaultFrame(), display: false)

        if activating {
            // Remember who to hand focus back to (ignore ourselves on re-toggle).
            if bundle != Bundle.main.bundleIdentifier {
                previousApp = front
            }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            // Now that the panel is key, tell the view to focus the search field.
            model.presentNonce &+= 1
        } else {
            panel.orderFrontRegardless()
        }

        // Refine the cached/bundle pick against the live terminal context and keep
        // the cache fresh (the process can change between opens).
        resolveContext(bundle: bundle, applyToVisible: true)
    }

    /// Resolve the terminal context off the main thread (it shells out to a CLI),
    /// cache it, and update the selected tab. `applyToVisible` switches a showing
    /// overlay; otherwise it warms the default tab while hidden, used on app
    /// activation so the next open is instant.
    func resolveContext(bundle: String?, applyToVisible: Bool) {
        let resolver = self.resolver
        Task.detached(priority: .userInitiated) { [weak self] in
            let cli = resolver.resolve(forFrontmostBundle: bundle)
            await self?.finalize(bundle: bundle, cli: cli, applyToVisible: applyToVisible)
        }
    }

    /// Warm the context cache for an app the user just switched to (overlay hidden).
    func warmContext(bundle: String?) { resolveContext(bundle: bundle, applyToVisible: false) }

    /// Combine the CLI-derived candidate with the frontmost-bundle match and pick
    /// the winner per the user's configured priority, then cache and apply it.
    private func finalize(
        bundle: String?,
        cli: (source: ContextSource, providerID: String)?,
        applyToVisible: Bool
    ) {
        var candidates: [ContextSource: String] = [:]
        if let cli { candidates[cli.source] = cli.providerID }
        if let bundle, let bp = model.registry.provider(forBundleID: bundle)?.id {
            candidates[.frontmostBundle] = bp
        }
        guard let winner = CheatCore.resolveContext(candidates: candidates, order: model.contextPriority) else { return }
        if let bundle { contextCache[bundle] = winner }
        guard model.hasSheet(winner) else { return }
        if applyToVisible {
            guard panel.isVisible else { return }
        } else {
            // Warming while hidden: only adjust the default tab if that app is
            // still frontmost (don't fight a newer activation).
            guard !panel.isVisible,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else { return }
        }
        model.select(providerID: winner)
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
