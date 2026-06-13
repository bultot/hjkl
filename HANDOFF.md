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
1. DONE — Process-aware terminal context (commit fda1528). CheatCore.TerminalContext
   parses `cmux top --json --processes` (active.surface_ref → surface node →
   foreground_pgids → process `path`) and classifies lazygit/neovim/claude-code/zsh
   (5 unit tests). App/ContextResolver.swift shells out to the cmux CLI (env
   CMUX_BUNDLED_CLI_PATH or /Applications/cmux.app/.../bin/cmux); OverlayController.show()
   uses it, falling back to bundle-id match. Live tab-switch needs owner's session.
2. DONE — App icon wired. AppDelegate has an HJKL_RENDER_ICON=dir mode that renders
   AppIconView natively at each appiconset pixel size (16…1024, scale 1, per-size
   canvas — crisper than downsampling one master). AppIconView is parameterized by
   `canvas` (all metrics are canvas fractions; 1024 output unchanged).
   scripts/gen-icon.sh builds → renders → writes App/Assets.xcassets/AppIcon.appiconset
   → rebuilds. project.yml sets ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon; the
   catalog is under App/ (picked up by the existing `sources: App`). Build embeds
   AppIcon.icns; Info.plist CFBundleIconName=AppIcon. Re-run gen-icon.sh after any
   AppIconView change. (Classic .appiconset, not the macOS 26 Icon Composer .icon —
   the artwork is a single flat SwiftUI layer.)
3. DONE — Global `/` search across ALL providers. CheatCore.searchSheets(_:query:)
   matches action + keys + app name across every enabled sheet, grouped by app
   (8 unit tests). `/` opens search mode in CheatSheetView: grouped flat-row results
   (SearchResultsView/SearchGroupCardView in Components.swift), ↑/↓ navigate every
   hit, ⏎ jumps to the matched app's tab and scrolls to the shortcut, esc clears
   then exits. Per-tab filter removed (filteredSections gone). Render dev tool:
   HJKL_SEARCH="focus" alongside HJKL_RENDER.
4. TODO — Owner verify live: `open build/Build/Products/Debug/hjkl.app` → ⌘⌥⌃/ and
   hold-⌥. Confirm panel shows + floats + transition + process-aware switching.

## Tests / build snapshot
43 tests / 12 suites green. App builds. Commits through fda1528 pushed to
github.com/bultot/hjkl. 7 providers registered. Render dev tool:
HJKL_RENDER=/tmp/x.png [HJKL_THEME=catppuccin-mocha] [HJKL_PROVIDER=neovim] <binary>.

## Key facts
- No Developer ID identity installed yet (ad-hoc "-" signing for dev).
- CheatCore is AppKit-free (pure Foundation) and unit-tested; app target is thin.
- Section type clashes with SwiftUI.Section → use CheatCore.Section in app code.
- NSPanel must be created lazily (not during app/scene setup) — done.
