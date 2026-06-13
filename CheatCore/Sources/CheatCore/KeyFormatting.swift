import Foundation

/// Converts config key tokens into display-ready glyph strings.
/// Shared by all providers so chips render consistently (⌘⌥⌃⇧ etc).
public enum KeyFormatting {
    /// Modifier/key token → glyph. Lowercased keys are matched.
    static let glyphs: [String: String] = [
        "cmd": "⌘", "command": "⌘", "super": "⌘", "meta": "⌘",
        "alt": "⌥", "opt": "⌥", "option": "⌥",
        "ctrl": "⌃", "control": "⌃",
        "shift": "⇧",
        "enter": "↵", "return": "↵",
        "esc": "⎋", "escape": "⎋",
        "tab": "⇥", "space": "␣",
        "backspace": "⌫", "delete": "⌦", "del": "⌦",
        "up": "↑", "down": "↓", "left": "←", "right": "→",
        "backtick": "`", "grave": "`",
        "minus": "-", "equal": "=", "slash": "/", "comma": ",", "period": ".",
        "semicolon": ";", "quote": "'", "leftsquarebracket": "[", "rightsquarebracket": "]",
    ]

    /// Order modifiers canonically (⌃⌥⇧⌘) like macOS does.
    private static let modifierOrder = ["⌃", "⌥", "⇧", "⌘"]

    /// Format a token sequence (e.g. ["cmd","alt","ctrl","h"]) into "⌃⌥⌘ H".
    public static func chord(_ tokens: [String]) -> String {
        var mods: [String] = []
        var keys: [String] = []
        for raw in tokens {
            let t = raw.lowercased()
            if let g = glyphs[t], modifierOrder.contains(g) {
                if !mods.contains(g) { mods.append(g) }
            } else if let g = glyphs[t] {
                keys.append(g)
            } else {
                keys.append(raw.count == 1 ? raw.uppercased() : raw.capitalized)
            }
        }
        mods.sort { (modifierOrder.firstIndex(of: $0) ?? 0) < (modifierOrder.firstIndex(of: $1) ?? 0) }
        let modPart = mods.joined()
        let keyPart = keys.joined(separator: " ")
        if modPart.isEmpty { return keyPart }
        if keyPart.isEmpty { return modPart }
        return modPart + " " + keyPart
    }

    /// Format a hyphen/plus-joined combo string (e.g. "cmd-alt-ctrl-h").
    public static func chord(fromCombo combo: String) -> String {
        let tokens = combo.split(whereSeparator: { $0 == "-" || $0 == "+" }).map(String.init)
        return chord(tokens)
    }
}
