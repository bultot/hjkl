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
            SettingsView(model: delegate.model)
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
        let view = RenderHarness(model: model)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

/// Placeholder settings — replaced in phase 4.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("hjkl").font(.largeTitle.bold())
            Text("Context-aware keyboard cheat sheet").foregroundStyle(.secondary)
            Divider()
            ForEach(model.sheets) { sheet in
                Label("\(sheet.title) — \(sheet.count) shortcuts", systemImage: sheet.symbol ?? "keyboard")
            }
        }
        .padding(24)
        .frame(width: 420, height: 260)
    }
}
