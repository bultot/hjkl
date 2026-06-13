import SwiftUI
import CheatCore

/// Stable row id for selection/scroll targeting.
func rowID(_ sectionID: String, _ sc: Shortcut) -> String { sectionID + "\u{1}" + sc.id }

/// Distribute sections into `count` height-balanced columns (greedy: each section
/// goes to the currently-shortest column). Keeps the grid visually even.
func balancedColumns(_ sections: [CheatCore.Section], _ count: Int) -> [[CheatCore.Section]] {
    guard count > 1 else { return [sections] }
    var cols = Array(repeating: [CheatCore.Section](), count: count)
    var heights = Array(repeating: 0, count: count)
    for s in sections {
        let i = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
        cols[i].append(s)
        heights[i] += s.shortcuts.count + 2   // +2 weights the title + card chrome
    }
    return cols
}

/// Multi-column grid of section cards that fills the available width.
struct SheetColumnsView: View {
    let sections: [CheatCore.Section]
    let palette: Palette
    var columns: Int = 3
    var selectedRowID: String? = nil

    var body: some View {
        let cols = balancedColumns(sections, columns)
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, colSections in
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(colSections) { s in
                        SectionCardView(section: s, palette: palette, selectedRowID: selectedRowID)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

/// Column count for a given section count (1–3), so sparse sheets don't over-split.
func columnCount(for sections: [CheatCore.Section]) -> Int {
    min(3, max(1, sections.count))
}

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
