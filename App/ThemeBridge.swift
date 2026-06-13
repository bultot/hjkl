import SwiftUI
import CheatCore

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// Resolves a `Theme` (from CheatCore, AppKit-free) into SwiftUI colors/materials.
/// When the theme `usesSystemMaterials`, prefer native semantic colors + materials
/// so hjkl blends into the OS; otherwise use the preset palette.
struct Palette {
    let theme: Theme

    var system: Bool { theme.usesSystemMaterials }
    var dark: Bool { theme.isDark }

    var textPrimary: Color { system ? .primary : theme.colors.textPrimary.color }
    var textSecondary: Color { system ? .secondary : theme.colors.textSecondary.color }
    var accent: Color { system ? .accentColor : theme.colors.accent.color }
    var sectionTitle: Color { system ? .secondary : theme.colors.sectionTitle.color }
    var divider: Color { system ? Color.primary.opacity(0.08) : theme.colors.divider.color }
    var surface: Color { system ? Color.primary.opacity(0.05) : theme.colors.surface.color }
    var keycapText: Color { system ? .primary : theme.colors.keycapText.color }
    var keycapBackground: Color { system ? Color.primary.opacity(0.10) : theme.colors.keycapBackground.color }

    /// Background fill behind the whole panel.
    @ViewBuilder var background: some View {
        if system {
            Rectangle().fill(.regularMaterial)
        } else {
            theme.colors.background.color.opacity(0.92)
                .background(.regularMaterial)
        }
    }
}
