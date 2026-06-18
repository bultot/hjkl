# hjkl

A context-aware keyboard cheat-sheet for macOS. Press one hotkey and see the
shortcuts for whatever you're currently in: your terminal multiplexer, your
window manager, your editor, your shell. Each sheet is read straight from that
tool's own config, so it stays in sync with your real keybindings instead of
drifting out of date in a static doc.

Native SwiftUI, runs as a menu-bar agent (no Dock icon, no main window),
read-only. macOS 26, Swift 6.

## Why

Every tool in a keyboard-driven setup has its own keymap, and most of them let
you rebind. A printed cheat sheet is wrong the moment you change a binding. hjkl
parses the live config files instead: it merges each tool's built-in defaults
with your overrides and shows the result, tagged by source (default, override,
or custom).

## What it shows

Eight providers ship today, each reading the tool's real config:

| Provider | Reads | Notes |
|----------|-------|-------|
| cmux | terminal multiplexer config | also drives process-aware switching (below) |
| AeroSpace | `~/.aerospace.toml` | window manager, always shown as a tab |
| skhd | `~/.config/skhd/skhdrc` | hotkey daemon (drives yabai), shown as a tab |
| Claude Code | settings / keybindings | |
| Ghostty | Ghostty config | terminal |
| lazygit | lazygit config | |
| Neovim | keymaps | |
| zsh | shell keybindings | |

A shortcut is tagged `builtinDefault`, `override`, or `custom` so you can see at
a glance what you changed. Popular shortcuts are marked `essential` and surfaced
with emphasis.

## Using it

- **Toggle:** `⌘⌥⌃/` shows or hides the overlay. No permissions required (it uses
  the KeyboardShortcuts framework).
- **Hold-to-peek (optional):** hold `⌥` to peek while held. Off by default;
  needs Accessibility permission, toggle it on in Settings.
- **Type to search:** start typing the moment the overlay opens and it filters
  the current app's shortcuts. `←`/`→` switch apps (the query carries over so you
  can scan the same term across tools), `↑`/`↓` walk the matches.
- **Search everything:** press `/` to escalate the same query to a search across
  every provider at once, grouped by app. `⏎` jumps to the matching tab and
  scrolls to the shortcut. `esc` clears the query, then closes.
- **Context aware:** the overlay opens on the tab for the app you're in. Inside a
  terminal it goes further: it probes the multiplexer to see the foreground
  process and opens on lazygit / Neovim / Claude Code / zsh accordingly, then
  switches tabs live as you move between panes.
- **Hide what you know:** hover a shortcut and click the eye, or press `⌘⌫` on the
  selected row, to drop it from the sheet and search. Review and restore hidden
  ones in Settings.

The overlay shows instantly and returns focus to the app you came from when it
hides. Themes: System, Catppuccin Mocha (default), Catppuccin Latte, Tokyo
Night. The panel chrome matches the active theme.

## Settings

Menu-bar icon → Settings:

- App toggles (which providers to show, hold-to-peek on/off).
- Hidden shortcuts (review and restore the ones you've dismissed).
- Context priority (order which source wins when several match, e.g. an attached
  tmux session vs the terminal's own bindings).
- Theme picker.
- Hotkey recorder (rebind the toggle).
- Open at login (SMAppService).

Config changes are picked up live via a file watcher; no restart needed.

## Build

```sh
xcodegen generate
xcodebuild -project hjkl.xcodeproj -scheme hjkl -configuration Debug \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build
```

Tests (the parsing core is pure Foundation and fully unit-tested):

```sh
cd CheatCore && swift test   # 51 tests / 13 suites
```

## Architecture

Two layers:

- **CheatCore** (SwiftPM package, AppKit-free, pure Foundation): the model
  (`Shortcut` / `Section` / `ShortcutSheet`), the `ShortcutProvider` protocol,
  the seven providers, cross-provider search, the terminal-context parser,
  theme presets, settings, and the config watcher. All unit-tested, all runnable
  off the main actor.
- **App** (the thin SwiftUI/AppKit target): the menu-bar agent, the
  non-activating `NSPanel` overlay, the cheat-sheet UI, the hotkey manager, the
  context resolver that shells out to the multiplexer CLI, settings UI, and the
  login item.

Adding a provider means implementing `ShortcutProvider` in CheatCore, adding it
to `allKnownProviders()`, and writing its tests. The app picks it up with no
changes. See [CLAUDE.md](CLAUDE.md) for the conventions agents follow.

## Distribution

Currently ad-hoc signed for local dev (no Developer ID identity installed). The
notarized Developer ID pipeline is written and documented in
[RELEASE.md](RELEASE.md) but not yet runnable (needs an Apple Developer ID
certificate). See [FUTURE.md](FUTURE.md) for what's planned next.

## Dev tools

Headless render harness (renders a sheet to PNG with no window, for UI review):

```sh
HJKL_RENDER=/tmp/x.png HJKL_THEME=catppuccin-mocha HJKL_PROVIDER=neovim \
  HJKL_SEARCH="focus" <app-binary>
```

`HJKL_RENDER_ICON=<dir>` renders the app icon at every appiconset size.
`HJKL_SHOW_ON_LAUNCH` shows the overlay on launch. `scripts/gen-icon.sh`
regenerates the icon set from `AppIconView`.
