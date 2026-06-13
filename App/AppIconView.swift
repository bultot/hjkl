import SwiftUI

/// macOS app icon for **hjkl** — the four vim navigation keys rendered as
/// rounded keycaps on a deep Catppuccin-Mocha gradient squircle.
///
/// Designed at 1024×1024 (downscaled by the integrator), so the motif is kept
/// bold: thick keycaps, large lowercase monospaced glyphs, no hairlines or tiny
/// text, so it stays legible at ≤32px. The area outside the squircle tile is
/// transparent (`Color.clear`); macOS supplies the on-disk mask, but inset +
/// rounded corners match the platform icon grid. The view is exactly
/// 1024×1024 — the integrator renders it straight to PNG.
struct AppIconView: View {
    // Catppuccin Mocha palette.
    private static let base = Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x2e / 255)   // #1e1e2e
    private static let surface0 = Color(red: 0x31 / 255, green: 0x32 / 255, blue: 0x44 / 255) // #313244
    private static let surface2 = Color(red: 0x45 / 255, green: 0x47 / 255, blue: 0x5a / 255) // #45475a
    private static let mauve = Color(red: 0xcb / 255, green: 0xa6 / 255, blue: 0xf7 / 255)    // #cba6f7
    private static let text = Color(red: 0xcd / 255, green: 0xd6 / 255, blue: 0xf4 / 255)     // #cdd6f4
    private static let crust = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x1b / 255)    // #11111b

    /// Logical edge of the square the icon is drawn into. Defaults to the 1024
    /// design size; the icon integrator passes the target pixel size so SwiftUI
    /// lays out (and rasterizes text/blur) natively at each appiconset resolution
    /// instead of downsampling a single 1024 master. All metrics below are
    /// fractions of `canvas`, so the 1024 render stays pixel-identical.
    var canvas: CGFloat = 1024
    private var inset: CGFloat { canvas * (100.0 / 1024.0) }   // tile is ~824×824 within the square
    private var tileRadius: CGFloat { canvas * (180.0 / 1024.0) }

    var body: some View {
        let tile = canvas - inset * 2

        ZStack {
            // Outside the tile stays transparent.
            Color.clear

            tileShape
                .frame(width: tile, height: tile)
                .overlay(keycaps(tile: tile))
                .overlay(rimHighlight)
                .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
                .shadow(color: Self.crust.opacity(0.55), radius: canvas * (48.0 / 1024.0), x: 0, y: canvas * (28.0 / 1024.0))
        }
        .frame(width: canvas, height: canvas)
    }

    // MARK: - Tile

    private var tileShape: some View {
        RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Self.surface2, Self.base, Self.crust],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Soft mauve glow pooling behind the keys.
                RadialGradient(
                    colors: [Self.mauve.opacity(0.30), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: canvas * (520.0 / 1024.0)
                )
            )
    }

    /// Thin inner light rim so the tile reads as a raised glass surface.
    private var rimHighlight: some View {
        RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.22), .clear, Self.crust.opacity(0.30)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: canvas * (6.0 / 1024.0)
            )
    }

    // MARK: - Keycaps

    private func keycaps(tile: CGFloat) -> some View {
        let size = tile * 0.205        // keycap edge
        let gap = tile * 0.045
        return HStack(spacing: gap) {
            keycap("h", size: size, accent: true)
            keycap("j", size: size, accent: false)
            keycap("k", size: size, accent: false)
            keycap("l", size: size, accent: false)
        }
    }

    /// One keycap: rounded rect with depth gradient, top highlight, drop shadow,
    /// and a bold lowercase monospaced letter. The leading `h` is mauve-accented
    /// (the brand's "home" key); the rest are light.
    private func keycap(_ letter: String, size: CGFloat, accent: Bool) -> some View {
        let radius = size * 0.26
        let capTop = accent ? Self.mauve : Self.text
        let capBottom = accent
            ? Self.mauve.opacity(0.78)
            : Color(red: 0xa6 / 255, green: 0xad / 255, blue: 0xc8 / 255) // muted text
        let letterColor = Self.crust

        return ZStack {
            // Recessed socket shadow under the cap.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Self.crust.opacity(0.45))
                .offset(y: size * 0.05)
                .blur(radius: size * 0.04)

            // Cap body.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [capTop, capBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Top inner highlight for the molded-plastic feel.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(size * 0.07)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: size * 0.012)
                )

            Text(letter)
                .font(.system(size: size * 0.56, weight: .bold, design: .monospaced))
                .foregroundStyle(letterColor)
        }
        .frame(width: size, height: size)
        .shadow(color: Self.crust.opacity(0.5), radius: size * 0.10, x: 0, y: size * 0.06)
    }
}

#Preview("App Icon 1024") {
    AppIconView()
        .background(.gray.opacity(0.3)) // shows the transparent corners in previews
}
