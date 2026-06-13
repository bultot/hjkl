# hjkl — build state & handoff

Context-aware keyboard cheat-sheet macOS app (Swift 6 / SwiftUI, macOS 26).
Repo: github.com/bultot/hjkl (private). Build: `xcodegen generate && xcodebuild
-project hjkl.xcodeproj -scheme hjkl -configuration Debug -derivedDataPath build
CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build`. Tests: `cd CheatCore &&
swift test` (38 tests / 11 suites green).

Headless UI review: `HJKL_RENDER=/tmp/x.png HJKL_THEME=catppuccin-mocha
HJKL_PROVIDER=<id> <app-binary>` renders a sheet to PNG (no window). Live overlay
(NSPanel) can't be shown from an automated shell — needs the owner's real session.

## Done (committed + pushed)
- Phase 0 scaffold (XcodeGen + CheatCore SwiftPM, menu-bar app, ad-hoc signed).
- Phase 1 parsers: CmuxProvider, AeroSpaceProvider, Theme presets, ConfigWatcher.
- Phase 2 overlay UI: non-activating NSPanel, SwiftUI sheet, multi-column balanced
  grid (1040x640), tabs, vim nav, `/` filter, essential star/bold emphasis,
  ThemeBridge (system + Catppuccin/Tokyo Night). Lazy overlay creation.
- Phase 3 invocation: HotkeyManager — ⌘⌥⌃/ toggle (KeyboardShortcuts, no perms) +
  hold-⌥ peek (global flagsChanged monitor, needs Accessibility). AeroSpace float
  rule added to dotfiles (nl.bultot.hjkl → layout floating).
- Phase 4-6: 7 providers (cmux, aerospace, claude-code, ghostty, lazygit, neovim,
  zsh) each = default keymap merged with config overrides (source:
  builtinDefault/override/custom). SettingsStore (JSON in App Support, first-run
  seed). Settings UI (app toggles, theme picker, KeyboardShortcuts.Recorder).
  Live reload via ConfigWatcher.
- Quick fade+rise transition (Reduce-Motion aware).

## In flight (uncommitted until this commit)
- App/AppIconView.swift — SwiftUI 1024 icon (hjkl keycaps, Catppuccin). NOT yet
  rendered to an AppIcon.appiconset / wired into project.yml.
- scripts/release.sh + hjkl.entitlements + ExportOptions.plist + RELEASE.md —
  Developer ID notarization pipeline. NOT runnable until owner has a Developer ID
  Application cert + `xcrun notarytool store-credentials`. entitlements not yet
  wired (set CODE_SIGN_ENTITLEMENTS in project.yml when adding a real one).

## Remaining work
1. Process-aware terminal context (the killer feature). When frontmost app ==
   com.cmuxterm.app, detect the FOCUSED pane's foreground process and switch the
   tab to lazygit/neovim/claude-code/zsh, else cmux.
   - cmux CLI (path: /Applications/cmux.app/Contents/Resources/bin/cmux, or env
     CMUX_BUNDLED_CLI_PATH): `cmux top --json` returns `active.surface_ref` (the
     focused surface) and `coding_agents[]` (e.g. id "claude" with pids). Use
     `cmux top --json --processes` to get per-surface process trees → find the
     active surface's foreground command. Map: lazygit→lazygit, nvim/vim→neovim,
     claude→claude-code, zsh/bash/-zsh→zsh, else cmux.
   - Add a ContextResolver in the app that shells out to the cmux CLI (only when
     frontmost is cmux), parses JSON, returns a provider id; call it from
     OverlayController.show() / ContextMonitor before selecting the tab.
   - Logic is testable from inside cmux (run the cmux commands); the panel display
     still needs the owner's live session.
2. Wire AppIconView → AppIcon.appiconset: add an HJKL_RENDER_ICON=path mode that
   renders AppIconView to 1024 PNG, then `sips` to all sizes + write Contents.json,
   set in project.yml. Then rebuild.
3. Global `/` search across ALL providers (not just the current tab): `/` opens a
   search that matches shortcuts across every enabled sheet, grouped by app, with
   keyboard selection. Currently `/` filters only the active sheet.
4. Owner to verify live: `open build/Build/Products/Debug/hjkl.app` → ⌘⌥⌃/ and
   hold-⌥. Confirm panel shows + floats + transition.

## Key facts
- No Developer ID identity installed yet (ad-hoc "-" signing for dev).
- CheatCore is AppKit-free (pure Foundation) and unit-tested; app target is thin.
- Section type clashes with SwiftUI.Section → use CheatCore.Section in app code.
- NSPanel must be created lazily (not during app/scene setup) — done.
