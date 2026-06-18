import Foundation

/// A source that can resolve which provider tab the overlay opens on. When more
/// than one applies (e.g. a terminal hosting an attached tmux session), the
/// user-configured order decides which wins.
public enum ContextSource: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The foreground process inside cmux's active pane (process-aware).
    case cmuxPaneProbe = "cmux-pane-probe"
    /// A tmux client attached in the frontmost terminal.
    case attachedTmux = "attached-tmux"
    /// The frontmost app's own bindings (bundle-id match).
    case frontmostBundle = "frontmost-bundle"

    public var id: String { rawValue }
}

public extension ContextSource {
    /// The historical hardcoded precedence: cmux pane probe, then attached tmux,
    /// then the frontmost app's own bindings.
    static let defaultPriority: [ContextSource] = [.cmuxPaneProbe, .attachedTmux, .frontmostBundle]
}

/// Return `order` deduped, with any missing sources appended in default order so
/// the result always covers every `ContextSource` (forward-compatible if a new
/// source is added or a stored array is partial/legacy).
public func normalizedContextPriority(_ order: [ContextSource]) -> [ContextSource] {
    var seen = Set<ContextSource>()
    var result: [ContextSource] = []
    for source in order where seen.insert(source).inserted { result.append(source) }
    for source in ContextSource.defaultPriority where seen.insert(source).inserted { result.append(source) }
    return result
}

/// Pick the winning provider id given the candidate each source produced and the
/// configured priority order. Sources without a candidate are skipped; the order
/// is normalized first so a partial order still resolves.
public func resolveContext(candidates: [ContextSource: String], order: [ContextSource]) -> String? {
    for source in normalizedContextPriority(order) {
        if let id = candidates[source] { return id }
    }
    return nil
}
