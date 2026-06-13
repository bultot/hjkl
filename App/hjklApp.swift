import SwiftUI
import CheatCore
import AppKit

@main
struct HjklApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("hjkl", systemImage: "keyboard") {
            Button("Show Cheat Sheet  (⌘⌥⌃/)") { delegate.showOverlay() }
            Button("Enable Hold-to-Peek (⌥)…") { delegate.enableHoldToPeek() }
            Divider()
            Button("Reload Configs") { delegate.model.reload() }
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit hjkl") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(model: delegate.model, onEnableHoldToPeek: { delegate.enableHoldToPeek() })
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var controller: OverlayController?
    private var contextMonitor: ContextMonitor?
    private var hotkeys: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dev tool: HJKL_RENDER=/path.png renders the sheet to a PNG (no window)
        // for headless design review, then exits. HJKL_THEME / HJKL_PROVIDER select.
        if let out = ProcessInfo.processInfo.environment["HJKL_RENDER"] {
            renderSheetPNG(to: out, themeID: ProcessInfo.processInfo.environment["HJKL_THEME"])
            NSApp.terminate(nil)
            return
        }

        // Dev tool: HJKL_RENDER_ICON=/dir renders AppIconView natively at each
        // appiconset pixel size (16…1024) into that directory, then exits.
        // Used by scripts/gen-icon.sh to build the AppIcon.appiconset.
        if let dir = ProcessInfo.processInfo.environment["HJKL_RENDER_ICON"] {
            renderAppIcons(toDir: dir)
            NSApp.terminate(nil)
            return
        }

        let hk = HotkeyManager(
            onToggle: { [weak self] in self?.toggleOverlay() },
            onPeekStart: { [weak self] in self?.showOverlay(activating: false) },
            onPeekEnd: { [weak self] in self?.hideOverlay() }
        )
        hk.start()
        hotkeys = hk

        if ProcessInfo.processInfo.environment["HJKL_SHOW_ON_LAUNCH"] != nil {
            DispatchQueue.main.async { [self] in showOverlay() }
        }
    }

    /// Build the overlay + context monitor on first use (deferred; building the
    /// panel during app/scene setup is unreliable).
    private func ensureController() {
        guard controller == nil else { return }
        controller = OverlayController(model: model)
        let monitor = ContextMonitor(model: model)
        monitor.start()
        contextMonitor = monitor
    }

    func showOverlay(activating: Bool = true) {
        ensureController()
        controller?.show(activating: activating)
    }

    func toggleOverlay() {
        ensureController()
        controller?.toggle()
    }

    func hideOverlay() {
        controller?.hide()
    }

    func enableHoldToPeek() {
        hotkeys?.ensureAccessibility(prompt: true)
    }

    @MainActor
    private func renderSheetPNG(to path: String, themeID: String?) {
        if let id = themeID, let t = Theme.presets.first(where: { $0.id == id }) { model.theme = t }
        if let pid = ProcessInfo.processInfo.environment["HJKL_PROVIDER"] { model.selectedID = pid }
        if let q = ProcessInfo.processInfo.environment["HJKL_SEARCH"] { model.filter = q }
        let view = RenderHarness(model: model)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    /// Render the app icon natively at each unique appiconset pixel size and
    /// write `icon_<px>.png` into `dir`. scale 1 + a per-size canvas means
    /// SwiftUI lays out and rasterizes each resolution on its own (crisp small
    /// icons) rather than downsampling one 1024 master.
    @MainActor
    private func renderAppIcons(toDir dir: String) {
        let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        for px in sizes {
            let renderer = ImageRenderer(content: AppIconView(canvas: px))
            renderer.scale = 1
            guard let img = renderer.nsImage,
                  let tiff = img.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            let path = (dir as NSString).appendingPathComponent("icon_\(Int(px)).png")
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
