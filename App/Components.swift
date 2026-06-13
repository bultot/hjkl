import SwiftUI
import CheatCore

/// Stable row id for selection/scroll targeting.
func rowID(_ sectionID: String, _ sc: Shortcut) -> String { sectionID + "\u{1}" + sc.id }

/// A single key-combo chip.
struct KeyCapView: View {
    let keys: String
    let palette: Palette

    var body: some View {
        Text(keys.isEmpty ? "—" : keys)
            .font(.system(.callout, design: .rounded).weight(.medium))
            .foregroundStyle(palette.keycapText)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(palette.keycapBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(palette.divider, lineWidth: 0.5))
            .frame(minWidth: 64, alignment: .leading)
            .fixedSize()
    }
}

/// One shortcut row: keycap + action, with emphasis for essential/popular ones.
struct ShortcutRowView: View {
    let shortcut: Shortcut
    let palette: Palette
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            KeyCapView(keys: shortcut.keys, palette: palette)
            Text(shortcut.action)
                .font(.callout)
                .fontWeight(shortcut.essential ? .semibold : .regular)
                .foregroundStyle(palette.textPrimary)
            if shortcut.essential {
                Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(palette.accent)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(selected ? palette.accent.opacity(0.18) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A titled card grouping a section's shortcuts.
struct SectionCardView: View {
    let section: CheatCore.Section
    let palette: Palette
    var selectedRowID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.sectionTitle)
                .tracking(0.6)
            VStack(spacing: 0) {
                ForEach(section.shortcuts) { sc in
                    ShortcutRowView(
                        shortcut: sc,
                        palette: palette,
                        selected: selectedRowID == rowID(section.id, sc)
                    )
                    .id(rowID(section.id, sc))
                }
            }
            .padding(.vertical, 4)
            .background(palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
