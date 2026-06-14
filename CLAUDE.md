# hjkl — project guide

Context-aware keyboard cheat-sheet for macOS. Menu-bar agent (LSUIElement, no
Dock icon, no main window), read-only. Swift 6, SwiftUI, macOS 26. Private repo:
github.com/bultot/hjkl.

Read [README.md](README.md) for what it does and [FUTURE.md](FUTURE.md) for
what's next. This file is the working guide for making changes.

## Layout

- **CheatCore/** — SwiftPM package, AppKit-free (pure Foundation), fully
  unit-tested. The model, the `ShortcutProvider` protocol, the seven providers,
  search, terminal-context parsing, themes, settings, config watcher. All logic
  that can be tested lives here and runs off the main actor.
- **App/** — thin SwiftUI/AppKit target. Menu-bar agent, the non-activating
  `NSPanel` overlay, the cheat-sheet UI, hotkey manager, context resolver,
  settings UI, login item. Keep it thin; push logic down into CheatCore.

## Build & test

```sh
xcodegen generate
xcodebuild -project hjkl.xcodeproj -scheme hjkl -configuration Debug \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build
cd CheatCore && swift test   # 66 tests / 15 suites, keep green
```

`project.yml` is the source of truth for the Xcode project; edit it, not the
generated `.xcodeproj`. Run `xcodegen generate` after changing it.

## Conventions

- **Adding a provider:** implement `ShortcutProvider` in
  `CheatCore/Sources/CheatCore/Providers/`, append it to `allKnownProviders()`,
  add a test suite with a config fixture under `CheatCore/Tests/.../Fixtures`.
  The app needs no changes. Tag shortcuts with the right `ShortcutSource`
  (`builtinDefault` / `override` / `custom`) by merging the tool's defaults with
  the parsed config.
- **`Section` clashes with `SwiftUI.Section`.** In app code use
  `CheatCore.Section` explicitly.
- **NSPanel must be created lazily**, not during app/scene setup (it crashes
  otherwise). It's pre-warmed one runloop tick after launch so the first hotkey
  press is instant.
- **Never block the main thread on show.** The overlay orders front instantly
  with the bundle-matched tab; the terminal-context probe runs detached and
  switches tabs when it returns.
- TDD: write the failing test first, then the parser. Providers are pure, so this
  is cheap. Conventional commits, short-lived branches off main.

## Dev tools

Headless render harness (no window needed):

```sh
HJKL_RENDER=/tmp/x.png HJKL_THEME=catppuccin-mocha HJKL_PROVIDER=neovim \
  HJKL_SEARCH="focus" <app-binary>
```

`HJKL_RENDER_ICON=<dir>` renders the icon at each appiconset size
(`scripts/gen-icon.sh` wraps build → render → write → rebuild; re-run after any
`AppIconView` change). `HJKL_SHOW_ON_LAUNCH` shows the overlay on launch.

## State

Functionally complete and verified live by the owner. The only outstanding work
is the notarized Developer ID release pipeline (`RELEASE.md`), which needs an
Apple Developer ID certificate before it can run. Everything else is in
[FUTURE.md](FUTURE.md).
