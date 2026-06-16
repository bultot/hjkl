import Foundation

/// A plain RGBA color value (components in 0...1). Foundation-only so the core
/// stays AppKit/SwiftUI-free; the app layer maps this to a SwiftUI `Color`.
public struct RGBA: Sendable, Hashable, Codable {
    public var r, g, b, a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Parse "#rrggbb" or "#rrggbbaa" (leading "#" optional). Returns nil on
    /// any malformed input (bad length, non-hex characters).
    public init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        guard let value = UInt32(s, radix: 16) else { return nil }

        let hasAlpha = s.count == 8
        if hasAlpha {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
    }
}

/// The set of semantic colors a cheat-sheet UI needs.
public struct ThemeColors: Sendable, Hashable, Codable {
    public var background: RGBA
    public var surface: RGBA
    public var surfaceElevated: RGBA
    public var textPrimary: RGBA
    public var textSecondary: RGBA
    public var accent: RGBA
    public var keycapBackground: RGBA
    public var keycapText: RGBA
    public var sectionTitle: RGBA
    public var divider: RGBA

    public init(
        background: RGBA,
        surface: RGBA,
        surfaceElevated: RGBA,
        textPrimary: RGBA,
        textSecondary: RGBA,
        accent: RGBA,
        keycapBackground: RGBA,
        keycapText: RGBA,
        sectionTitle: RGBA,
        divider: RGBA
    ) {
        self.background = background
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.keycapBackground = keycapBackground
        self.keycapText = keycapText
        self.sectionTitle = sectionTitle
        self.divider = divider
    }
}

/// A named, data-only theme. The app layer renders it (or, when
/// `usesSystemMaterials` is true, prefers native materials/accent and treats
/// `colors` as a fallback).
public struct Theme: Identifiable, Sendable, Hashable, Codable {
    public var id: String
    public var name: String
    public var isDark: Bool
    /// When true, the app should use native materials/accent and treat
    /// `colors` as a fallback rather than the source of truth.
    public var usesSystemMaterials: Bool
    public var colors: ThemeColors

    public init(
        id: String,
        name: String,
        isDark: Bool,
        usesSystemMaterials: Bool,
        colors: ThemeColors
    ) {
        self.id = id
        self.name = name
        self.isDark = isDark
        self.usesSystemMaterials = usesSystemMaterials
        self.colors = colors
    }
}

// MARK: - Presets

public extension Theme {
    /// Neutral light palette used as a fallback while the app drives the look
    /// from native system materials and the user's accent color.
    static let system = Theme(
        id: "system",
        name: "System",
        isDark: false,
        usesSystemMaterials: true,
        colors: ThemeColors(
            background: RGBA(hex: "#f2f2f7")!,
            surface: RGBA(hex: "#ffffff")!,
            surfaceElevated: RGBA(hex: "#fbfbfd")!,
            textPrimary: RGBA(hex: "#1c1c1e")!,
            textSecondary: RGBA(hex: "#6c6c70")!,
            accent: RGBA(hex: "#0a84ff")!,
            keycapBackground: RGBA(hex: "#e5e5ea")!,
            keycapText: RGBA(hex: "#1c1c1e")!,
            sectionTitle: RGBA(hex: "#3a3a3c")!,
            divider: RGBA(hex: "#d1d1d6")!
        )
    )

    /// Catppuccin Mocha (dark). https://catppuccin.com
    static let catppuccinMocha = Theme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        isDark: true,
        usesSystemMaterials: false,
        colors: ThemeColors(
            background: RGBA(hex: "#1e1e2e")!,      // base
            surface: RGBA(hex: "#313244")!,         // surface0
            surfaceElevated: RGBA(hex: "#45475a")!, // surface1
            textPrimary: RGBA(hex: "#cdd6f4")!,     // text
            textSecondary: RGBA(hex: "#a6adc8")!,   // subtext0
            accent: RGBA(hex: "#cba6f7")!,          // mauve
            keycapBackground: RGBA(hex: "#45475a")!, // surface1
            keycapText: RGBA(hex: "#cdd6f4")!,      // text
            sectionTitle: RGBA(hex: "#cba6f7")!,    // mauve
            divider: RGBA(hex: "#45475a")!          // surface1
        )
    )

    /// Catppuccin Latte (light). https://catppuccin.com
    static let catppuccinLatte = Theme(
        id: "catppuccin-latte",
        name: "Catppuccin Latte",
        isDark: false,
        usesSystemMaterials: false,
        colors: ThemeColors(
            background: RGBA(hex: "#eff1f5")!,      // base
            surface: RGBA(hex: "#ccd0da")!,         // surface0
            surfaceElevated: RGBA(hex: "#bcc0cc")!, // surface1
            textPrimary: RGBA(hex: "#4c4f69")!,     // text
            textSecondary: RGBA(hex: "#6c6f85")!,   // subtext0
            accent: RGBA(hex: "#8839ef")!,          // mauve
            keycapBackground: RGBA(hex: "#bcc0cc")!, // surface1
            keycapText: RGBA(hex: "#4c4f69")!,      // text
            sectionTitle: RGBA(hex: "#8839ef")!,    // mauve
            divider: RGBA(hex: "#bcc0cc")!          // surface1
        )
    )

    /// Tokyo Night (dark). https://github.com/enkia/tokyo-night-vscode-theme
    static let tokyoNight = Theme(
        id: "tokyo-night",
        name: "Tokyo Night",
        isDark: true,
        usesSystemMaterials: false,
        colors: ThemeColors(
            background: RGBA(hex: "#1a1b26")!,      // bg
            surface: RGBA(hex: "#24283b")!,         // surface
            surfaceElevated: RGBA(hex: "#414868")!, // elevated
            textPrimary: RGBA(hex: "#c0caf5")!,     // text
            textSecondary: RGBA(hex: "#9aa5ce")!,   // subtext
            accent: RGBA(hex: "#7aa2f7")!,          // accent
            keycapBackground: RGBA(hex: "#414868")!, // keycap
            keycapText: RGBA(hex: "#c0caf5")!,      // text
            sectionTitle: RGBA(hex: "#7aa2f7")!,    // accent
            divider: RGBA(hex: "#414868")!          // divider
        )
    )

    /// Gruvbox Material (dark). Matches Ghostty's "Gruvbox Material Dark".
    /// https://github.com/sainnhe/gruvbox-material
    static let gruvboxMaterialDark = Theme(
        id: "gruvbox-material-dark",
        name: "Gruvbox Material Dark",
        isDark: true,
        usesSystemMaterials: false,
        colors: ThemeColors(
            background: RGBA(hex: "#282828")!,      // bg0
            surface: RGBA(hex: "#32302f")!,         // bg1
            surfaceElevated: RGBA(hex: "#45403d")!, // bg3
            textPrimary: RGBA(hex: "#d4be98")!,     // fg0
            textSecondary: RGBA(hex: "#928374")!,   // grey1
            accent: RGBA(hex: "#d8a657")!,          // yellow
            keycapBackground: RGBA(hex: "#45403d")!, // bg3
            keycapText: RGBA(hex: "#ddc7a1")!,      // fg1
            sectionTitle: RGBA(hex: "#d8a657")!,    // yellow
            divider: RGBA(hex: "#45403d")!          // bg3
        )
    )

    /// All built-in themes, in display order.
    static let presets: [Theme] = [.system, .catppuccinMocha, .catppuccinLatte, .tokyoNight, .gruvboxMaterialDark]
}
