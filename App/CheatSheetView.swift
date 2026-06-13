import SwiftUI
import CheatCore

/// The overlay content: app tabs and the selected provider's shortcuts when
/// browsing; a global search across every enabled app when `/` is pressed.
/// Fully keyboard-driven (vim keys + arrows).
struct CheatSheetView: View {
    @Bindable var model: AppModel
    let onClose: () -> Void

    @State private var selection: Int = 0
    /// When set, the next selectedID/filter change targets this row instead of
    /// resetting to 0 (used when Enter jumps from a search hit into its app).
    @State private var pendingTarget: String? = nil

    /// Where keyboard focus lives. Kept on exactly one of these so the panel's
    /// key handler keeps working after the search field is dismissed.
    private enum Field: Hashable { case panel, search }
    @FocusState private var focus: Field?

    private var isSearching: Bool { focus == .search }
    private var sheet: ShortcutSheet? { model.selectedSheet }

    // Browse mode: the selected sheet's full sections.
    private var browseSections: [CheatCore.Section] { sheet?.sections ?? [] }
    private var browseFlat: [(sid: String, sc: Shortcut)] {
        browseSections.flatMap { s in s.shortcuts.map { (s.id, $0) } }
    }

    // Search mode: matches across all enabled sheets, grouped by app.
    private var searchGroups: [SearchGroup] { model.searchGroups }
    private var searchFlat: [SearchHit] { searchGroups.flatMap { $0.hits } }

    private var navCount: Int { isSearching ? searchFlat.count : browseFlat.count }

    private func rowID(_ sid: String, _ sc: Shortcut) -> String { sid + "\u{1}" + sc.id }

    private var selectedBrowseRowID: String? {
        guard browseFlat.indices.contains(selection) else { return nil }
        let f = browseFlat[selection]
        return rowID(f.sid, f.sc)
    }
    private var selectedHitID: String? {
        guard searchFlat.indices.contains(selection) else { return nil }
        return searchFlat[selection].id
    }
    private var scrollTargetID: String? { isSearching ? selectedHitID : selectedBrowseRowID }

    var body: some View {
        let p = model.palette
        VStack(spacing: 0) {
            header(p)
            Divider().overlay(p.divider)
            content(p)
            footer(p)
        }
        .frame(width: 1040, height: 640)
        .background { p.background }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(p.divider, lineWidth: 1)
        }
        .foregroundStyle(p.textPrimary)
        .focusable()
        .focused($focus, equals: .panel)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleKey($0, palette: p) }
        .onChange(of: model.selectedID) { applyPendingOrReset() }
        .onChange(of: model.filter) { applyPendingOrReset() }
        .onAppear { focus = .panel }
    }

    /// Resolve a pending jump target to its row index, otherwise reset selection.
    private func applyPendingOrReset() {
        if let t = pendingTarget,
           let idx = browseFlat.firstIndex(where: { rowID($0.sid, $0.sc) == t }) {
            selection = idx
            pendingTarget = nil
        } else if pendingTarget == nil {
            selection = 0
        }
    }

    // MARK: header

    @ViewBuilder private func header(_ p: Palette) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isSearching ? "magnifyingglass" : (sheet?.symbol ?? "keyboard"))
                    .foregroundStyle(p.accent)
                Text(isSearching ? "Search" : (sheet?.title ?? "hjkl"))
                    .font(.title3.weight(.semibold))
                if isSearching, !model.filter.isEmpty {
                    Text("\(model.searchHitCount) across \(searchGroups.count)")
                        .font(.caption).foregroundStyle(p.textSecondary)
                }
                Spacer()
                searchField(p)
            }
            tabBar(p)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder private func searchField(_ p: Palette) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(p.textSecondary)
            TextField("Search all apps (/)", text: $model.filter)
                .textFieldStyle(.plain)
                .foregroundStyle(p.textPrimary)
                .tint(p.accent)
                .frame(width: 220)
                .focused($focus, equals: .search)
                .onSubmit { jumpToSelectedHit() }
                // The focused NSTextField field editor swallows Escape before it
                // reaches the panel's .onKeyPress, so handle it here directly.
                .onExitCommand {
                    if model.filter.isEmpty { exitSearch() } else { model.filter = "" }
                }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(p.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(isSearching ? p.accent.opacity(0.5) : .clear))
    }

    @ViewBuilder private func tabBar(_ p: Palette) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(model.sheets.enumerated()), id: \.element.id) { idx, s in
                let active = !isSearching && s.id == model.selectedID
                HStack(spacing: 5) {
                    Image(systemName: s.symbol ?? "keyboard").font(.caption2)
                    Text(s.title).font(.callout.weight(active ? .semibold : .regular))
                    Text("\(idx + 1)").font(.caption2.monospaced()).opacity(0.5)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundStyle(active ? p.keycapText : p.textSecondary)
                .background(active ? p.accent.opacity(0.22) : p.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? p.accent.opacity(0.5) : .clear))
                .contentShape(Capsule())
                .onTapGesture { focus = .panel; model.selectTab(index: idx) }
            }
            Spacer()
        }
    }

    // MARK: content

    @ViewBuilder private func content(_ p: Palette) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isSearching {
                    searchContent(p)
                } else {
                    browseContent(p)
                }
            }
            .onChange(of: selection) {
                guard let rid = scrollTargetID else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(rid, anchor: .center) }
            }
        }
    }

    @ViewBuilder private func searchContent(_ p: Palette) -> some View {
        if model.filter.trimmingCharacters(in: .whitespaces).isEmpty {
            placeholder("Type to search \(model.sheets.count) apps…", p)
        } else if searchGroups.isEmpty {
            placeholder("No matches for “\(model.filter)”.", p)
        } else {
            SearchResultsView(groups: searchGroups, palette: p, selectedHitID: selectedHitID)
                .padding(18)
        }
    }

    @ViewBuilder private func browseContent(_ p: Palette) -> some View {
        if browseSections.isEmpty {
            placeholder("No shortcuts.", p)
        } else {
            SheetColumnsView(
                sections: browseSections, palette: p,
                columns: columnCount(for: browseSections), selectedRowID: selectedBrowseRowID
            )
            .padding(18)
        }
    }

    @ViewBuilder private func placeholder(_ text: String, _ p: Palette) -> some View {
        Text(text)
            .foregroundStyle(p.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    // MARK: footer

    @ViewBuilder private func footer(_ p: Palette) -> some View {
        HStack(spacing: 14) {
            if isSearching {
                hint("↑ ↓", "move", p); hint("⏎", "open", p); hint("esc", "back", p)
            } else {
                hint("h l", "tabs", p); hint("j k", "move", p); hint("/", "search", p); hint("esc", "close", p)
            }
            Spacer()
            Text(isSearching ? "\(model.searchHitCount) matches" : "\(sheet?.count ?? 0) shortcuts")
                .font(.caption2).foregroundStyle(p.textSecondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(p.surface.opacity(0.5))
    }

    @ViewBuilder private func hint(_ k: String, _ label: String, _ p: Palette) -> some View {
        HStack(spacing: 4) {
            Text(k).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(p.textPrimary)
            Text(label).font(.caption2).foregroundStyle(p.textSecondary)
        }
    }

    // MARK: keyboard

    private func handleKey(_ press: KeyPress, palette p: Palette) -> KeyPress.Result {
        // While the search field has focus, intercept only navigation; typing
        // (and everything else) falls through to the TextField.
        if isSearching {
            switch press.key {
            case .escape:
                if model.filter.isEmpty { exitSearch() } else { model.filter = "" }
                return .handled
            case .upArrow: move(-1); return .handled
            case .downArrow: move(1); return .handled
            case .return: jumpToSelectedHit(); return .handled
            default: return .ignored
            }
        }

        switch press.key {
        case .escape:
            onClose(); return .handled
        case .leftArrow:
            model.selectNextTab(-1); return .handled
        case .rightArrow:
            model.selectNextTab(1); return .handled
        case .upArrow:
            move(-1); return .handled
        case .downArrow:
            move(1); return .handled
        default:
            break
        }

        switch press.characters {
        case "q": onClose(); return .handled
        case "/": enterSearch(); return .handled
        case "h": model.selectNextTab(-1); return .handled
        case "l": model.selectNextTab(1); return .handled
        case "j": move(1); return .handled
        case "k": move(-1); return .handled
        case "g": selection = 0; return .handled
        case "G": selection = max(0, navCount - 1); return .handled
        case let s where s.count == 1 && s >= "1" && s <= "9":
            model.selectTab(index: Int(s)! - 1); return .handled
        default:
            return .ignored
        }
    }

    private func enterSearch() {
        pendingTarget = nil
        selection = 0
        focus = .search
    }

    private func exitSearch() {
        focus = .panel
        pendingTarget = nil
        model.filter = ""
        selection = 0
    }

    /// Enter on a search hit: switch to that app's tab and land on the shortcut.
    private func jumpToSelectedHit() {
        guard searchFlat.indices.contains(selection) else { return }
        let hit = searchFlat[selection]
        pendingTarget = rowID(hit.sectionTitle, hit.shortcut)
        focus = .panel
        model.select(providerID: hit.sheetID)   // sets selectedID + clears filter → applyPendingOrReset
    }

    private func move(_ delta: Int) {
        guard navCount > 0 else { return }
        selection = min(max(0, selection + delta), navCount - 1)
    }
}
