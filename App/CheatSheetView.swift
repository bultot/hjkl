import SwiftUI
import CheatCore

/// The overlay content: app tabs and the selected app's shortcuts. Typing filters
/// the selected app immediately; `/` escalates the same query to a search across
/// every enabled app. Fully keyboard-driven: arrows move and switch apps, every
/// other key feeds the always-focused search field.
struct CheatSheetView: View {
    @Bindable var model: AppModel
    let onClose: () -> Void

    @State private var selection: Int = 0
    /// When set, the next selectedID/filter change targets this row instead of
    /// resetting to 0 (used when Enter jumps from a search hit into its app).
    @State private var pendingTarget: String? = nil

    /// Where keyboard focus lives. The search field holds focus so typing always
    /// works; the panel stays focusable so its key handler keeps receiving events.
    private enum Field: Hashable { case panel, search }
    @FocusState private var focus: Field?

    private var isGlobal: Bool { model.globalSearch }
    private var hasQuery: Bool { !model.filter.trimmingCharacters(in: .whitespaces).isEmpty }
    private var sheet: ShortcutSheet? { model.selectedSheet }
    private var appTitle: String { sheet?.title ?? "this app" }

    // Current-app view: the selected sheet's sections, narrowed to the query
    // (the full sheet when the query is blank).
    private var appSections: [CheatCore.Section] { model.currentAppSections }
    private var appFlat: [(sid: String, sc: Shortcut)] {
        appSections.flatMap { s in s.shortcuts.map { (s.id, $0) } }
    }

    // Global search: matches across all enabled sheets, grouped by app.
    private var searchGroups: [SearchGroup] { model.searchGroups }
    private var searchFlat: [SearchHit] { searchGroups.flatMap { $0.hits } }

    private var navCount: Int { isGlobal ? searchFlat.count : appFlat.count }

    private func rowID(_ sid: String, _ sc: Shortcut) -> String { sid + "\u{1}" + sc.id }

    private var selectedAppRowID: String? {
        guard appFlat.indices.contains(selection) else { return nil }
        let f = appFlat[selection]
        return rowID(f.sid, f.sc)
    }
    private var selectedHitID: String? {
        guard searchFlat.indices.contains(selection) else { return nil }
        return searchFlat[selection].id
    }
    private var scrollTargetID: String? { isGlobal ? selectedHitID : selectedAppRowID }

    /// The opaque cheat-sheet card. The window is larger than this by
    /// `shadowMargin` on every side so the Raycast-style soft shadow has room
    /// to draw into transparent space instead of being clipped.
    static let cardSize = CGSize(width: 1040, height: 640)
    static let cornerRadius: CGFloat = 18
    static let shadowMargin: CGFloat = 60
    static var windowSize: CGSize {
        CGSize(width: cardSize.width + shadowMargin * 2,
               height: cardSize.height + shadowMargin * 2)
    }

    var body: some View {
        let p = model.palette
        VStack(spacing: 0) {
            header(p)
            Divider().overlay(p.divider)
            content(p)
            footer(p)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background { p.background }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(p.divider, lineWidth: 1)
        }
        // Raycast-style soft drop shadow: a broad ambient layer plus a tighter
        // contact layer for depth. Cast off the clipped rounded card.
        .shadow(color: .black.opacity(0.34), radius: 36, x: 0, y: 22)
        .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
        .padding(Self.shadowMargin)
        .foregroundStyle(p.textPrimary)
        .focusable()
        .focused($focus, equals: .panel)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleKey($0, palette: p) }
        .onChange(of: model.selectedID) { applyPendingOrReset() }
        .onChange(of: model.filter) { applyPendingOrReset() }
        .onChange(of: model.globalSearch) { selection = 0 }
        // Keep focus on the search field so the user can type immediately.
        .onAppear { focus = .search }
    }

    /// Resolve a pending jump target to its row index, otherwise reset selection.
    private func applyPendingOrReset() {
        if let t = pendingTarget,
           let idx = appFlat.firstIndex(where: { rowID($0.sid, $0.sc) == t }) {
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
                Image(systemName: isGlobal ? "magnifyingglass" : (sheet?.symbol ?? "keyboard"))
                    .foregroundStyle(p.accent)
                Text(isGlobal ? "All apps" : appTitle)
                    .font(.title3.weight(.semibold))
                if isGlobal, hasQuery {
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
        let active = isGlobal || hasQuery
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(p.textSecondary)
            TextField(isGlobal ? "Search all apps…" : "Search \(appTitle)  ·  / all apps",
                      text: $model.filter)
                .textFieldStyle(.plain)
                .foregroundStyle(p.textPrimary)
                .tint(p.accent)
                .frame(width: 260)
                .focused($focus, equals: .search)
                .onSubmit { if isGlobal { jumpToSelectedHit() } }
                // The focused NSTextField field editor swallows Escape before it
                // reaches the panel's .onKeyPress, so handle it here directly.
                .onExitCommand { handleEscape() }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(p.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(active ? p.accent.opacity(0.5) : .clear))
    }

    @ViewBuilder private func tabBar(_ p: Palette) -> some View {
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
                .contentShape(Capsule())
                .onTapGesture { if let i = model.sheets.firstIndex(where: { $0.id == s.id }) {
                    model.selectTab(index: i); selection = 0
                } }
            }
            Spacer()
        }
    }

    // MARK: content

    @ViewBuilder private func content(_ p: Palette) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isGlobal {
                    searchContent(p)
                } else {
                    appContent(p)
                }
            }
            .onChange(of: selection) {
                guard let rid = scrollTargetID else { return }
                proxy.scrollTo(rid, anchor: .center)
            }
        }
    }

    @ViewBuilder private func searchContent(_ p: Palette) -> some View {
        if !hasQuery {
            placeholder("Type to search \(model.sheets.count) apps…", p)
        } else if searchGroups.isEmpty {
            placeholder("No matches for “\(model.filter)”.", p)
        } else {
            SearchResultsView(groups: searchGroups, palette: p, selectedHitID: selectedHitID)
                .padding(18)
        }
    }

    @ViewBuilder private func appContent(_ p: Palette) -> some View {
        if appSections.isEmpty {
            placeholder(hasQuery ? "No matches in \(appTitle) for “\(model.filter)”.  Press / to search all apps."
                                 : "No shortcuts.", p)
        } else {
            SheetColumnsView(
                sections: appSections, palette: p,
                columns: columnCount(for: appSections), selectedRowID: selectedAppRowID
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
            if isGlobal {
                hint("↑ ↓", "move", p); hint("⏎", "open", p); hint("esc", "back", p)
            } else {
                hint("↑ ↓", "move", p); hint("← →", "apps", p)
                hint("/", "all apps", p); hint("esc", hasQuery ? "clear" : "close", p)
            }
            Spacer()
            Text(footerCount).font(.caption2).foregroundStyle(p.textSecondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(p.surface.opacity(0.5))
    }

    private var footerCount: String {
        if isGlobal { return "\(model.searchHitCount) matches" }
        if hasQuery { return "\(appFlat.count) matches" }
        return "\(sheet?.count ?? 0) shortcuts"
    }

    @ViewBuilder private func hint(_ k: String, _ label: String, _ p: Palette) -> some View {
        HStack(spacing: 4) {
            Text(k).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(p.textPrimary)
            Text(label).font(.caption2).foregroundStyle(p.textSecondary)
        }
    }

    // MARK: keyboard

    private func handleKey(_ press: KeyPress, palette p: Palette) -> KeyPress.Result {
        switch press.key {
        case .escape:
            handleEscape(); return .handled
        case .leftArrow:
            switchApp(-1); return .handled
        case .rightArrow:
            switchApp(1); return .handled
        case .upArrow:
            move(-1); return .handled
        case .downArrow:
            move(1); return .handled
        case .return:
            if isGlobal { jumpToSelectedHit() }
            return .handled
        default:
            break
        }

        // `/` escalates the current query to an all-apps search. Everything else
        // (letters, digits, backspace, …) falls through to the search field.
        if press.characters == "/" {
            if !isGlobal { model.globalSearch = true; selection = 0 }
            return .handled
        }
        return .ignored
    }

    /// Escape ladder: clear the query (back to browsing the app), then close.
    private func handleEscape() {
        if hasQuery {
            model.filter = ""
            model.globalSearch = false
        } else if isGlobal {
            model.globalSearch = false
        } else {
            onClose()
        }
        selection = 0
    }

    private func switchApp(_ delta: Int) {
        model.selectNextTab(delta)
        selection = 0
    }

    /// Enter on a search hit: switch to that app's tab and land on the shortcut.
    private func jumpToSelectedHit() {
        guard searchFlat.indices.contains(selection) else { return }
        let hit = searchFlat[selection]
        pendingTarget = rowID(hit.sectionTitle, hit.shortcut)
        model.select(providerID: hit.sheetID)   // sets selectedID + resets search → applyPendingOrReset
    }

    private func move(_ delta: Int) {
        guard navCount > 0 else { return }
        selection = min(max(0, selection + delta), navCount - 1)
    }
}
