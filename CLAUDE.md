# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Vignette: a native macOS menu bar app (SwiftUI, `LSUIElement`, no Dock icon)
for multi-monitor setups:

- Per-display brightness control, including external monitors.
- "영화 감상 모드" / Movie Mode: pick the screen that's playing video, and every
  other connected display gets dimmed with a dark gradient overlay. Optionally,
  displays that support it also have their real backlight lowered.

Localized in Korean (source language), English, and Japanese — see
[Localization](#localization) below. Target: macOS 13 Ventura+.

## Build / run / project generation

The Xcode project/workspace (`Vignette.xcodeproj`, `Vignette.xcworkspace`) is
**generated** by [Tuist](https://tuist.dev) from `Tuist.swift` (global config)
and `Project.swift` (targets) — both are gitignored, do not hand-edit them;
edit the manifests and regenerate instead:

```sh
tuist generate --no-open
```

Build/run from the command line:

```sh
xcodebuild -workspace Vignette.xcworkspace -scheme Vignette -configuration Debug -destination 'platform=macOS' build
open /Users/lee/Library/Developer/Xcode/DerivedData/Vignette-*/Build/Products/Debug/Vignette.app
```

Or run `tuist generate` (opens Xcode by default) and run from there. There is
no test target yet.

Since this is `LSUIElement` (agent app), it has no Dock icon or app switcher
entry when running — look for it in the menu bar.

## Releasing

`.github/workflows/release.yml` builds, packages, and publishes a release
whenever a `v*` tag is pushed: it ad-hoc signs the Release build (no
Developer ID is configured for this project), packages it into a DMG via
`scripts/make_dmg.sh`, attaches that DMG to a GitHub Release, and
auto-commits the resulting `version`/`sha256` into `Casks/vignette.rb`.

To cut a release: bump `MARKETING_VERSION` in `Project.swift`, commit, then
tag and push `vX.Y.Z` matching it.

`Casks/vignette.rb` is a Homebrew cask served straight out of this repo
(not a separate `homebrew-*` tap repo), so users tap it with an explicit
URL: `brew tap mrKangHo/vignette https://github.com/mrKangHo/vignette`.

## Architecture

```
VignetteApp (@main)
├── MenuBarExtra → MenuBarContentView   (quick toggles, lives in the menu bar)
└── settingsWindowController.show(...)  (opens SettingsView in a plain, self-owned
                                          NSWindow — see "Settings window" below)

AppState (ObservableObject, @MainActor)
├── DisplayManager          — enumerates NSScreen/CGDirectDisplayID, refreshes on
│                              NSApplication.didChangeScreenParametersNotification
├── BrightnessCoordinator   — picks a BrightnessControlling backend per display
│                              and persists DisplaySettings (UserDefaults, keyed
│                              by each display's CGDisplayCreateUUIDFromDisplayID)
├── OverlayCoordinator      — owns the one DimmingWindow per display and decides
│                              how dark it should be (see below); AppState feeds
│                              it `baseDimProvider` from the brightness sliders,
│                              MovieModeController feeds it movie-mode's forced
│                              minimum for non-active displays
├── MovieModeController     — movie-mode state + hardware-brightness side effects
│                              (see below); delegates all visuals to OverlayCoordinator
└── SettingsWindowController — owns the Settings NSWindow (see below)
```

### Settings window

`SettingsWindowController` creates and owns a plain `NSWindow` with an
`NSHostingView(rootView: SettingsView(...))`, shown/raised via
`NSApp.activate` + `makeKeyAndOrderFront`. This is deliberate, not
incidental: the "standard" pre-macOS-14 way to open a SwiftUI `Settings`
scene from a button (`NSApp.sendAction(Selector(("showSettingsWindow:")), ...)`)
depends on the app having a normal main menu to host the hidden "Settings…"
command that selector mimics — `LSUIElement` menu-bar-only apps never get
one, so that selector has nowhere to route to and silently does nothing.
Owning the window directly sidesteps the problem entirely and works
regardless of menu bar/Dock presence.

### Display identity

Displays are matched to persisted settings by `CGDisplayCreateUUIDFromDisplayID`,
not by `CGDirectDisplayID` — the latter is not stable across reboots/port
changes, the former is. `DisplayManager.displays` is the single source of truth
for "what's connected right now"; everything else reacts to its `@Published`
changes.

### Dimming has two independent layers, shared by the brightness slider and movie mode

1. **Software overlay (always available):** `DimmingWindow` is a borderless,
   click-through (`ignoresMouseEvents`), maximum-level `NSWindow` per screen
   painting a `CAGradientLayer` vignette; `OverlayCoordinator` owns one per
   display and is the only thing that ever touches them. Its effective dim
   for a display is `max(baseDim, movieModeIntensity if movie mode is active
   and this isn't the active display, else 0)`. `baseDim` (supplied by
   `AppState.baseDim(for:)`) is `1 - brightness` *unless* hardware brightness
   is supported for that display, in which case it's `0` — otherwise a
   display with working hardware control would get a vignette painted over
   an already-correctly-dimmed screen. This is also why the plain brightness
   slider visibly does something even on displays with no hardware support:
   without this overlay fallback, moving it changed only a persisted number.
2. **Hardware brightness (best-effort, automatic whenever supported — there
   is no user-facing toggle; `AppState.baseDim`/`MovieModeController.applyHardwareDimming`
   just call `BrightnessCoordinator.supportsHardwareBrightness(for:)` and use
   it if it returns true):** actually lowers the backlight, via `BrightnessControlling`:
   - `BuiltInBrightnessController` — built-in panel, via the private
     `DisplayServices.framework` (`DisplayServicesGetBrightness`/
     `SetBrightness`), the same mechanism macOS's own Control Center uses.
   - `DDCBrightnessController` — external monitors, via DDC/CI (VESA MCCS)
     tunneled through the private, undocumented `IOAVService` I2C transport
     (`Sources/Vignette/Services/DDC/IOAVServiceBridge.swift`). On Apple Silicon
     there is no public way to correlate an `IOAVService`/`DCPAVServiceProxy`
     entry with a `CGDirectDisplayID`, so matching falls back to enumeration
     order among external displays — this is a known limitation shared by
     every third-party macOS brightness tool (MonitorControl, Lunar, etc.),
     not something to "fix" without deeper IORegistry correlation work.

**`supportsBrightnessControl` is probe-based, not symbol-existence-based.**
Both controllers cache the result of an actual round trip (a real
`DisplayServicesGetBrightness` call / a real DDC/CI Get-VCP exchange) the
first time they're asked about a display, not just whether the private
symbols resolved or an `IOAVService` handle could be created — the latter
routinely succeeds even for a monitor that will never actually respond to
DDC/CI, which previously made `AppState.baseDim` skip the overlay (assuming
hardware would handle it) while the real write silently failed, leaving the
plain brightness slider with no visible effect at all. The cache is
invalidated in `DDCBrightnessController.registerExternalDisplayIndex` when a
display's enumeration index changes, since that can mean a different
physical monitor.

**Every symbol both hardware controllers call is private/undocumented** and
resolved via `dlopen`/`dlsym` at runtime specifically so that a future macOS
removing them degrades to "hardware brightness unsupported" (overlay still
works) instead of crashing or failing to launch. Because of this:

- The app **cannot ship on the Mac App Store** (private API usage) and should
  be distributed Developer ID–signed/notarized outside the MAS.
- App Sandbox is off (`Resources/Vignette/Vignette.entitlements`) — sandboxing
  would block the private framework/IOKit access these controllers need.
- Treat `BrightnessControlling` failures as expected, not exceptional; never
  add a stronger availability assumption than "may or may not work on this
  Mac/monitor/cable."

### Persisted state

`DisplaySettings` (currently just `brightness`) is `Codable`, stored as JSON
in `UserDefaults` under `display-settings.<uuid>` per display — see
`BrightnessCoordinator.settings(for:)`/`saveSettings(_:for:)`.

## Localization

All user-facing strings are literal Korean text passed directly to
`Text(_:)`/`Label(_:)`/`Toggle(_:)`/`Picker(_:)`/`.help(_:)` (SwiftUI treats
a `String` literal there as a `LocalizedStringKey` automatically) or, for the
one AppKit `NSWindow.title` case, wrapped in `String(localized:)`
(`SettingsWindowController.swift`). Korean is the source language
(`CFBundleDevelopmentRegion` in `Info.plist`); every key's English and
Japanese translation lives in `Resources/Vignette/Localizable.xcstrings`, a
String Catalog Xcode compiles into `ko.lproj`/`en.lproj`/`ja.lproj` at build
time — no code changes needed to add a language, only new entries in that
file. **The literal Korean string in the Swift source *is* the catalog key**,
so renaming a key means updating it in both the `.swift` call site and the
catalog's JSON key, or the lookup falls back to showing the raw Korean text in
every locale. The app's own name, "Vignette", is intentionally left out of
the catalog — it's a brand name and stays identical across all three locales.

## File layout

```
Sources/Vignette/
├── VignetteApp.swift          entry point / Scenes
├── Models/                    Display, DisplaySettings (plain data types)
├── Services/                  DisplayManager, BrightnessCoordinator,
│   └── DDC/                   BrightnessControlling backends + IOAVService bridge
├── Overlay/                   DimmingWindow, OverlayCoordinator, MovieModeController
├── ViewModels/AppState.swift  wires everything together for the views
└── Views/                     MenuBarContentView, SettingsView, DisplayRowView,
                                SettingsWindowController
Resources/Vignette/            Info.plist, entitlements, Assets.xcassets,
                                Localizable.xcstrings
Tuist.swift / Project.swift    Tuist manifests — source of truth for the project
```
