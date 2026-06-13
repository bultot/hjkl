import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggle the sticky, interactive overlay. Default ⌘⌥⌃/.
    static let toggleCheatSheet = Self(
        "toggleCheatSheet",
        default: .init(.slash, modifiers: [.command, .option, .control])
    )
}

/// Wires up the two invocation modes:
///  - a global toggle hotkey (Carbon-based, no permissions needed), and
///  - hold-⌥ to peek (global modifier monitor; needs Accessibility/Input Monitoring).
@MainActor
final class HotkeyManager {
    private let onToggle: () -> Void
    private let onPeekStart: () -> Void
    private let onPeekEnd: () -> Void

    /// Hold a single modifier this long before peeking (avoids accidental flashes).
    var holdThreshold: TimeInterval = 0.25
    /// Which bare modifier triggers hold-to-peek.
    var peekModifier: NSEvent.ModifierFlags = .option

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var peekWork: DispatchWorkItem?
    private var peeking = false

    init(onToggle: @escaping () -> Void,
         onPeekStart: @escaping () -> Void,
         onPeekEnd: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onPeekStart = onPeekStart
        self.onPeekEnd = onPeekEnd
    }

    func start() {
        KeyboardShortcuts.onKeyUp(for: .toggleCheatSheet) { [onToggle] in onToggle() }
    }

    /// Install/remove the hold-to-peek modifier monitors. Off by default; the
    /// global monitor fires while other apps are focused, the local monitor
    /// covers the case where our own (key) panel is up.
    func setPeekEnabled(_ enabled: Bool) {
        if enabled {
            guard globalMonitor == nil else { return }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
                MainActor.assumeIsolated { self?.handleFlags(e.modifierFlags) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
                MainActor.assumeIsolated { self?.handleFlags(e.modifierFlags) }
                return e
            }
        } else {
            if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
            if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
            peekWork?.cancel(); peekWork = nil
            if peeking { peeking = false; onPeekEnd() }
        }
    }

    /// Returns true if Accessibility is trusted (hold-to-peek needs it). Prompts once.
    @discardableResult
    func ensureAccessibility(prompt: Bool) -> Bool {
        // Literal value of kAXTrustedCheckOptionPrompt (the global is not Sendable).
        return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let active = flags.intersection(.deviceIndependentFlagsMask)
        let onlyPeekMod = active == peekModifier

        if onlyPeekMod {
            peekWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                peeking = true
                onPeekStart()
            }
            peekWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: work)
        } else {
            peekWork?.cancel()
            peekWork = nil
            if peeking {
                peeking = false
                onPeekEnd()
            }
        }
    }
}
