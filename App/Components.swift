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
    var onHide: ((Shortcut) -> Void)? = nil

    var body: some View {
        let cols = balancedColumns(sections, columns)
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, colSections in
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(colSections) { s in
                        SectionCardView(section: s, palette: palette, selectedRowID: selectedRowID, onHide: onHide)
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

// MARK: - Global search

/// Distribute search groups into `count` height-balanced columns (greedy), so a
/// broad query doesn't pile every app into one tall column.
func balancedGroups(_ groups: [SearchGroup], _ count: Int) -> [[SearchGroup]] {
    guard count > 1 else { return [groups] }
    var cols = Array(repeating: [SearchGroup](), count: count)
    var heights = Array(repeating: 0, count: count)
    for g in groups {
        let i = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
        cols[i].append(g)
        heights[i] += g.hits.count + 2   // +2 weights the app header
    }
    return cols
}

/// Multi-column grid of per-app result cards for global search.
struct SearchResultsView: View {
    let groups: [SearchGroup]
    let palette: Palette
    var selectedHitID: String? = nil
    var onHide: ((String, Shortcut) -> Void)? = nil

    private var columns: Int { min(3, max(1, groups.count)) }

    var body: some View {
        let cols = balancedGroups(groups, columns)
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, colGroups in
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(colGroups) { g in
                        SearchGroupCardView(group: g, palette: palette, selectedHitID: selectedHitID, onHide: onHide)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

/// One app's matches: header (icon + name + count) then flat shortcut rows.
struct SearchGroupCardView: View {
    let group: SearchGroup
    let palette: Palette
    var selectedHitID: String? = nil
    var onHide: ((String, Shortcut) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: group.symbol ?? "keyboard")
                    .font(.caption).foregroundStyle(palette.accent)
                Text(group.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.sectionTitle)
                    .tracking(0.6)
                Text("\(group.count)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(palette.surface, in: Capsule())
            }
            VStack(spacing: 0) {
                ForEach(group.hits) { hit in
                    ShortcutRowView(
                        shortcut: hit.shortcut,
                        palette: palette,
                        selected: selectedHitID == hit.id,
                        onHide: onHide.map { cb in { cb(group.sheetID, hit.shortcut) } }
                    )
                    .id(hit.id)
                }
            }
            .padding(.vertical, 4)
            .background(palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// The currently hovered shortcut's explanation plus where its `?` sits, bubbled
/// up so the overlay can draw a single floating bubble on top. AppKit tooltips
/// (`.help`) don't fire in the borderless non-activating panel, so we render our
/// own from SwiftUI hover state.
struct DetailTip {
    let text: String
    let anchor: Anchor<CGRect>
}

struct DetailTipKey: PreferenceKey {
    static let defaultValue: DetailTip? = nil
    static func reduce(value: inout DetailTip?, nextValue: () -> DetailTip?) {
        value = value ?? nextValue()
    }
}

/// The floating explanation bubble shown next to a hovered `?`. Opaque base so
/// it stays readable over the cards behind it.
struct DetailTipView: View {
    let text: String
    let palette: Palette

    var body: some View {
        Text(text)
            .font(.callout)
            .lineSpacing(3)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 380, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background {
                ZStack {
                    palette.background
                    palette.surface.opacity(0.7)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.divider, lineWidth: 0.5))
            }
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
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
/// When `onHide` is set, a hide button reveals on hover (and on selection, so the
/// keyboard path has a visible target).
struct ShortcutRowView: View {
    let shortcut: Shortcut
    let palette: Palette
    var selected: Bool = false
    var onHide: (() -> Void)? = nil

    @State private var hovering = false
    @State private var tipHovering = false

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
            if let detail = shortcut.detail, !detail.isEmpty {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(tipHovering ? palette.accent : palette.textSecondary)
                    .onHover { tipHovering = $0 }
                    .anchorPreference(key: DetailTipKey.self, value: .bounds) {
                        tipHovering ? DetailTip(text: detail, anchor: $0) : nil
                    }
            }
            Spacer(minLength: 8)
            if let onHide {
                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Hide this shortcut (⌘⌫)")
                .opacity(hovering || selected ? 1 : 0)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(selected ? palette.accent.opacity(0.18) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
    }
}

/// A titled card grouping a section's shortcuts.
struct SectionCardView: View {
    let section: CheatCore.Section
    let palette: Palette
    var selectedRowID: String? = nil
    var onHide: ((Shortcut) -> Void)? = nil

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
                        selected: selectedRowID == rowID(section.id, sc),
                        onHide: onHide.map { cb in { cb(sc) } }
                    )
                    .id(rowID(section.id, sc))
                }
            }
            .padding(.vertical, 4)
            .background(palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
