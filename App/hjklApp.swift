import SwiftUI
import CheatCore

@main
struct HjklApp: App {
    var body: some Scene {
        MenuBarExtra("hjkl", systemImage: "keyboard") {
            Text("hjkl — keyboard cheat sheet")
            Divider()
            Button("Quit hjkl") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}

/// Placeholder settings — replaced in phase 4.
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("hjkl").font(.largeTitle.bold())
            Text("Context-aware keyboard cheat sheet")
                .foregroundStyle(.secondary)
            Text("Known providers: \(ProviderRegistry.defaults.providers.map(\.displayName).joined(separator: ", "))")
                .font(.callout)
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}
