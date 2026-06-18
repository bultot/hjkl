import Testing
import Foundation
@testable import CheatCore

@Suite("ContextPriority")
struct ContextPriorityTests {
    @Test("default order: cmux probe wins, then tmux, then bundle")
    func defaultOrder() {
        #expect(ContextSource.defaultPriority == [.cmuxPaneProbe, .attachedTmux, .frontmostBundle])
    }

    @Test("raw values are stable (guards the persisted format)")
    func rawValues() {
        #expect(ContextSource.cmuxPaneProbe.rawValue == "cmux-pane-probe")
        #expect(ContextSource.attachedTmux.rawValue == "attached-tmux")
        #expect(ContextSource.frontmostBundle.rawValue == "frontmost-bundle")
    }

    @Test("resolve picks the first source in order that has a candidate")
    func picksByOrder() {
        let candidates: [ContextSource: String] = [.attachedTmux: "tmux", .frontmostBundle: "ghostty"]
        #expect(resolveContext(candidates: candidates, order: ContextSource.defaultPriority) == "tmux")
    }

    @Test("Ghostty hosting tmux: default order → tmux; frontmost-first → ghostty")
    func ghosttyTmux() {
        let candidates: [ContextSource: String] = [.attachedTmux: "tmux", .frontmostBundle: "ghostty"]
        #expect(resolveContext(candidates: candidates, order: [.attachedTmux, .frontmostBundle]) == "tmux")
        #expect(resolveContext(candidates: candidates, order: [.frontmostBundle, .attachedTmux]) == "ghostty")
    }

    @Test("sources without a candidate are skipped")
    func skipsMissing() {
        let candidates: [ContextSource: String] = [.frontmostBundle: "safari"]
        #expect(resolveContext(candidates: candidates, order: ContextSource.defaultPriority) == "safari")
    }

    @Test("no candidates → nil")
    func noneResolves() {
        #expect(resolveContext(candidates: [:], order: ContextSource.defaultPriority) == nil)
    }

    @Test("normalize fills missing sources in default order")
    func normalizeFills() {
        #expect(normalizedContextPriority([.frontmostBundle]) == [.frontmostBundle, .cmuxPaneProbe, .attachedTmux])
    }

    @Test("normalize dedupes")
    func normalizeDedupes() {
        let out = normalizedContextPriority([.attachedTmux, .attachedTmux, .frontmostBundle])
        #expect(out == [.attachedTmux, .frontmostBundle, .cmuxPaneProbe])
    }

    @Test("resolve honors a partial order via normalization")
    func partialOrderResolves() {
        // Only frontmostBundle listed; tmux candidate present but ranks lower after fill.
        let candidates: [ContextSource: String] = [.frontmostBundle: "ghostty", .attachedTmux: "tmux"]
        #expect(resolveContext(candidates: candidates, order: [.frontmostBundle]) == "ghostty")
    }
}
