# hjkl — future ideas

The app is functionally complete for its original goal. This is the parking lot
for what could come next, roughly ordered by how soon it matters. Nothing here
is committed work; it's a menu to pick from.

## Ship it

The one thing standing between hjkl and other people using it.

- **Notarized Developer ID release.** The pipeline is written
  (`scripts/release.sh`, `RELEASE.md`) but needs an Apple Developer ID
  Application certificate and a `notarytool` keychain profile. Once those exist,
  run it, build and ship from `/Applications` so the login item registers a
  stable path.
- **Auto-update via Sparkle.** Fits the non-sandboxed agent model, signs its own
  update archives (EdDSA). Wire it after the first notarized build exists.
- **Distribution channel.** A DMG (`create-dmg`) or a Homebrew cask. A cask is
  probably the right fit for the target audience (keyboard-driven terminal
  users).

## More providers

The whole value scales with coverage. Each is an isolated `ShortcutProvider`
plus tests, no app changes.

- tmux, Zellij, WezTerm (other multiplexers/terminals).
- Yabai / skhd (alternative window managers).
- Helix, VS Code, Zed (other editors).
- fzf, ripgrep, bat and friends (the CLI tools people forget the flags for).
- Kitty, Alacritty.
- git aliases parsed from `~/.gitconfig`.

A provider "starter" template or a `scripts/new-provider.sh` would lower the bar
for adding them.

## Smarter context

Process-aware switching already works inside the multiplexer. Extensions:

- Generalize the terminal probe beyond cmux so process-awareness works in any
  terminal, not just the one multiplexer that exposes a JSON state dump.
- Mode-aware sheets: show Neovim's *insert* vs *normal* bindings depending on the
  current mode, not a flat list.
- Recently-used ranking: track which shortcuts the user actually opens the sheet
  to look up and float those, per provider.
- **Configurable context priority.** When several providers are nested (Ghostty
  hosting tmux hosting Claude Code), the resolver currently has a fixed
  precedence (cmux pane probe > attached tmux > frontmost bundle). Expose this in
  Settings as a user-ordered priority list so the user decides which tab wins
  when more than one matches. Default to the current order; the resolver reads
  the configured order instead of the hardcoded one.

## UX polish

- **Quick-action / palette mode:** instead of only displaying a binding, let `⏎`
  on a result trigger it (where the tool exposes a command interface). Turns the
  cheat sheet into a launcher.
- **Per-provider config override UI:** today config paths are auto-detected;
  expose a field to point a provider at a non-standard path.
- **Custom sheets:** let users hand-author a sheet (YAML/JSON) for a tool that
  has no parser yet, so coverage isn't gated on writing Swift.
- **Hide learned shortcuts.** Let the user dismiss a shortcut they already know
  so it drops out of the sheet, reducing noise over time. Reversible: store the
  hidden set in Settings keyed by provider + shortcut id (`keys\u{1}action`), add
  a per-row affordance to hide, and a Settings section to review and restore.
  Optionally a toggle to show hidden ones dimmed instead of removing them.
- **Pinning / favorites:** a user-curated "my essentials" tab across tools.
- **More themes**, and honoring the system accent color.

## Engineering

- **Snapshot tests for the SwiftUI overlay** using the existing `HJKL_RENDER`
  harness, so UI regressions get caught in CI, not by eye.
- **CI** (GitHub Actions): run `swift test` on CheatCore and a build of the app
  target on every push.
- **Decouple from the cmux CLI dependency** for context resolution, or make the
  CLI path configurable and degrade gracefully when it's absent (it already falls
  back to bundle-id matching).
- **Localize** the UI strings (currently EN only).

## Wild ideas

- A "teach me" mode that periodically surfaces a shortcut you've never used.
- Export the merged keymap (defaults + overrides) as markdown, for people who
  still want a printable sheet.
- A companion that diffs your config against the tool's defaults and tells you
  what you've actually customized.
