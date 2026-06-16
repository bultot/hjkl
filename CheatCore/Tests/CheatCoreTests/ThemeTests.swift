import Testing
import Foundation
@testable import CheatCore

@Suite("Theme")
struct ThemeTests {
    @Test("RGBA parses 6-digit hex")
    func parseHex6() {
        let c = RGBA(hex: "#cba6f7")
        #expect(c != nil)
        #expect(abs(c!.r - 0.796) < 0.005)
        #expect(abs(c!.a - 1.0) < 0.0001)
    }

    @Test("RGBA parses 8-digit hex with alpha and tolerates missing #")
    func parseHex8() {
        let c = RGBA(hex: "cba6f780")
        #expect(c != nil)
        #expect(abs(c!.r - 0.796) < 0.005)
        #expect(abs(c!.a - (128.0 / 255.0)) < 0.0001)
    }

    @Test("RGBA rejects malformed input")
    func parseHexBad() {
        #expect(RGBA(hex: "#fff") == nil)
        #expect(RGBA(hex: "#gggggg") == nil)
        #expect(RGBA(hex: "") == nil)
        #expect(RGBA(hex: "#cba6f7ff00") == nil)
    }

    @Test("There are exactly five presets")
    func presetCount() {
        #expect(Theme.presets.count == 5)
    }

    @Test("Preset ids are unique")
    func presetIdsUnique() {
        let ids = Theme.presets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every preset accent is fully opaque")
    func presetAccentsOpaque() {
        for theme in Theme.presets {
            #expect(abs(theme.colors.accent.a - 1.0) < 0.0001)
        }
    }

    @Test("Only the system preset uses system materials")
    func systemMaterialsFlag() {
        #expect(Theme.system.usesSystemMaterials)
        for theme in Theme.presets where theme.id != "system" {
            #expect(!theme.usesSystemMaterials)
        }
    }
}
