# Vignette

A lightweight macOS menu bar app for multi-monitor brightness, and a one-click
"Movie Mode" that dims every other display so the one playing something gets
your full attention.

Available in Korean, English, and Japanese.

## Features

- **Per-display brightness** — a slider for every connected display, right
  from the menu bar.
- **Movie Mode** — pick which display is playing, and every other connected
  display dims with a soft gradient overlay. Turn it off and everything
  returns to normal.
- **Real backlight control when possible** — on displays that actually
  support it (the built-in panel, and external monitors that respond to
  DDC/CI), Vignette drives the real backlight instead of just painting an
  overlay on top. It falls back to the overlay automatically everywhere
  else, so the brightness slider always does *something* visible.

## Requirements

- macOS 13 Ventura or later
- An Apple Silicon or Intel Mac

## Installation

Vignette uses private, undocumented macOS frameworks to control display
backlights (see [Why private APIs](#why-private-apis) below), so it can't be
distributed through the Mac App Store. Build it from source:

```sh
git clone https://github.com/mrKangHo/vignette.git
cd vignette
tuist generate
```

This opens the generated Xcode project — build and run the `Vignette`
scheme. [Tuist](https://tuist.dev) is required (`brew install tuist`).

To build from the command line instead:

```sh
tuist generate --no-open
xcodebuild -workspace Vignette.xcworkspace -scheme Vignette -configuration Debug -destination 'platform=macOS' build
```

## Usage

Vignette lives in the menu bar (look for the two-display icon — it has no
Dock icon). Click it to:

- Adjust each connected display's brightness.
- Toggle Movie Mode and pick which display is currently playing.

A "Settings" window (gear icon in the popover) has a slider for how strong
Movie Mode's dimming effect is.

## Why private APIs

There is no public macOS API for controlling a display's backlight —
neither the built-in panel's nor an external monitor's over DDC/CI. Vignette
uses the same undocumented mechanisms that macOS's own Control Center and
tools like MonitorControl/Lunar rely on, resolved dynamically via
`dlopen`/`dlsym` so that if Apple ever removes them, Vignette degrades to
"software overlay only" instead of crashing.

Because of this:

- It's Developer ID/notarization-distributable, not Mac App Store-eligible.
- External monitor brightness control (DDC/CI) is best-effort — it depends
  on your monitor, cable, and any USB-C/Thunderbolt hub in between, and may
  simply not work for a given setup. The software overlay is the guaranteed
  fallback.

## License

[MIT](LICENSE)
