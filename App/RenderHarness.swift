import SwiftUI
import CheatCore

/// A non-scrolling, control-free rendition of the current sheet used by
/// `HJKL_RENDER` (ImageRenderer doesn't draw ScrollView content or TextFields
/// offscreen). Mirrors the live overlay's look for headless design review.
struct RenderHarness: View {
    let model: AppModel

    var body: some View {
        let p = model.palette
        let sheet = model.selectedSheet
        VStack(spacing: 0) {
            // header
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: sheet?.symbol ?? "keyboard").foregroundStyle(p.accent)
                    Text(sheet?.title ?? "hjkl").font(.title3.weight(.semibold)).foregroundStyle(p.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(p.textSecondary)
                        Text("Filter (/)").font(.callout).foregroundStyle(p.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(p.surface, in: Capsule())
                }
                HStack(spacing: 6) {
                    ForEach(Array(model.sheets.enumerated()), id: \.element.id) { idx, s in
                        let active = s.id == model.selectedID
                        HStack(spacing: 5) {
                            Image(systemName: s.symbol ?? "keyboard").font(.caption2)
                            Text(s.title).font(.callout.weight(active ? .semibold : .regular))
                            Text("\(idx + 1)").font(.caption2.monospaced()).opacity(0.5)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(active ? p.keycapText : p.textSecondary)
                        .background(active ? p.accent.opacity(0.22) : p.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(active ? p.accent.opacity(0.5) : .clear))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 10)

            Divider().overlay(p.divider)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(sheet?.sections ?? []) { section in
                    SectionCardView(section: section, palette: p)
                }
            }
            .padding(18)

            Spacer(minLength: 0)
        }
        .frame(width: 760)
        .background { p.background }
    }
}
