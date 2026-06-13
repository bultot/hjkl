import SwiftUI
import CheatCore

/// The overlay content: app tabs, a live filter, and the selected provider's
/// shortcut sections. Fully keyboard-driven (vim keys).
struct CheatSheetView: View {
    @Bindable var model: AppModel
    let onClose: () -> Void

    @State private var selection: Int = 0
    @FocusState private var searchFocused: Bool

    private var sheet: ShortcutSheet? { model.selectedSheet }
    private var sections: [CheatCore.Section] { sheet.map { model.filteredSections($0) } ?? [] }

    /// Flattened (sectionIndex, shortcut) pairs for j/k navigation.
    private var flat: [(sid: String, shortcut: Shortcut)] {
        sections.flatMap { s in s.shortcuts.map { (s.id, $0) } }
    }
    private func rowID(_ sid: String, _ sc: Shortcut) -> String { sid + "\u{1}" + sc.id }

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
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleKey($0, palette: p) }
        .onChange(of: model.selectedID) { selection = 0 }
        .onChange(of: model.filter) { selection = 0 }
    }

    // MARK: header

    @ViewBuilder private func header(_ p: Palette) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: sheet?.symbol ?? "keyboard")
                    .foregroundStyle(p.accent)
                Text(sheet?.title ?? "hjkl")
                    .font(.title3.weight(.semibold))
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
            TextField("Filter (/)", text: $model.filter)
                .textFieldStyle(.plain)
                .frame(width: 180)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(p.surface, in: Capsule())
    }

    @ViewBuilder private func tabBar(_ p: Palette) -> some View {
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
                .contentShape(Capsule())
                .onTapGesture { model.selectTab(index: idx) }
            }
            Spacer()
        }
    }

    // MARK: content

    private var selectedRowID: String? {
        guard flat.indices.contains(selection) else { return nil }
        let f = flat[selection]
        return rowID(f.sid, f.shortcut)
    }

    @ViewBuilder private func content(_ p: Palette) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if sections.isEmpty {
                    Text(model.filter.isEmpty ? "No shortcuts." : "No matches for “\(model.filter)”.")
                        .foregroundStyle(p.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    SheetColumnsView(
                        sections: sections, palette: p,
                        columns: columnCount(for: sections), selectedRowID: selectedRowID
                    )
                    .padding(18)
                }
            }
            .onChange(of: selection) {
                guard let rid = selectedRowID else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(rid, anchor: .center) }
            }
        }
    }

    // MARK: footer

    @ViewBuilder private func footer(_ p: Palette) -> some View {
        HStack(spacing: 14) {
            hint("h l", "tabs", p); hint("j k", "move", p); hint("/", "filter", p); hint("esc", "close", p)
            Spacer()
            Text("\(sheet?.count ?? 0) shortcuts").font(.caption2).foregroundStyle(p.textSecondary)
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
        // While typing in the filter, let the field handle everything except esc.
        if searchFocused {
            if press.key == .escape {
                if model.filter.isEmpty { searchFocused = false } else { model.filter = "" }
                return .handled
            }
            return .ignored
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
        case "/": searchFocused = true; return .handled
        case "h": model.selectNextTab(-1); return .handled
        case "l": model.selectNextTab(1); return .handled
        case "j": move(1); return .handled
        case "k": move(-1); return .handled
        case "g": selection = 0; scrollFix(); return .handled
        case "G": selection = max(0, flat.count - 1); return .handled
        case let s where s.count == 1 && s >= "1" && s <= "9":
            model.selectTab(index: Int(s)! - 1); return .handled
        default:
            return .ignored
        }
    }

    private func move(_ delta: Int) {
        guard !flat.isEmpty else { return }
        selection = min(max(0, selection + delta), flat.count - 1)
    }

    private func scrollFix() { /* selection change triggers scroll via onChange */ }
}
