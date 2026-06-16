import SwiftUI
import CheatCore

/// A non-scrolling, control-free rendition of the current sheet used by
/// `HJKL_RENDER` (ImageRenderer doesn't draw ScrollView content or TextFields
/// offscreen). Mirrors the live overlay's look for headless design review.
struct RenderHarness: View {
    let model: AppModel

    private var isGlobal: Bool { model.globalSearch }
    private var hasQuery: Bool { !model.filter.trimmingCharacters(in: .whitespaces).isEmpty }
    private var appTitle: String { model.selectedSheet?.title ?? "this app" }

    var body: some View {
        let p = model.palette
        VStack(spacing: 0) {
            // header
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: isGlobal ? "magnifyingglass" : (model.selectedSheet?.symbol ?? "keyboard")).foregroundStyle(p.accent)
                    Text(isGlobal ? "All apps" : appTitle).font(.title3.weight(.semibold)).foregroundStyle(p.textPrimary)
                    if isGlobal, hasQuery {
                        Text("\(model.searchHitCount) across \(model.searchGroups.count)").font(.caption).foregroundStyle(p.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(p.textSecondary)
                        Text(hasQuery ? model.filter : (isGlobal ? "Search all apps…" : "Search \(appTitle)  ·  / all apps")).font(.callout).foregroundStyle(p.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(p.surface, in: Capsule())
                }
                HStack(spacing: 6) {
                    ForEach(Array(model.sheets.enumerated()), id: \.element.id) { _, s in
                        let active = !isGlobal && s.id == model.selectedID
                        HStack(spacing: 5) {
                            Image(systemName: s.symbol ?? "keyboard").font(.caption2)
                            Text(s.title).font(.callout.weight(active ? .semibold : .regular))
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

            if isGlobal {
                SearchResultsView(groups: model.searchGroups, palette: p)
                    .padding(18)
            } else {
                SheetColumnsView(
                    sections: model.currentAppSections, palette: p,
                    columns: columnCount(for: model.currentAppSections)
                )
                .padding(18)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 1040)
        .background { p.background }
    }
}
