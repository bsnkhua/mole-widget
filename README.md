# mole-mac-widget

[![CI](https://github.com/bsnkhua/mole-mac-widget/actions/workflows/ci.yml/badge.svg)](https://github.com/bsnkhua/mole-mac-widget/actions/workflows/ci.yml)

A native macOS desktop widget showing live system metrics in the terminal aesthetic of the `mo status` CLI (mole): a borderless window living at desktop level — above the wallpaper, below application windows.

<img src="assets/widget.webp" width="520" alt="Mole Widget on the desktop">


## Features

- **Header** — chip, RAM, macOS version, uptime and a composite health score (0–100)
- **CPU** — total usage, top-3 busiest cores, load average, usage trend sparkline
- **Memory** — used/free, total, cached, available
- **Disk** — root volume usage, used/free space, read/write speed
- **Power** — charge level, battery health, status, cycle count, temperature
- **Network** — download/upload sparklines with rates, active interface and local IP
- **Processes** — top-3 by CPU with memory footprint
- Click any section title to open Activity Monitor
- Visible on all Spaces, ignored by Mission Control and ⌘Tab, stays below regular windows
- Drag it anywhere with the mouse; position is remembered across launches
- Resizable: drag the right edge to adjust the width (490–880 pt), saved across launches
- 🔒 Clickable lock icon on the widget (plus a "Lock position" menu item) pins both position and size
- Settings in the menu bar: background opacity, visible sections, refresh rate (1/2/5 s)
- Launch at login toggle; no Dock icon

## Requirements

- macOS 14+
- Swift 6 toolchain — Command Line Tools are enough (`xcode-select --install`), full Xcode is not required

## Install

### Homebrew

```bash
brew install bsnkhua/tap/mole-mac-widget
mole-widget   # launch the widget
```

The formula builds the widget from source on your machine (~30 s; needs only
the Command Line Tools that Homebrew already requires). Because the app is
built locally, Gatekeeper has no objections to the unsigned bundle.

Quit it any time from the menu bar icon → **Quit mole-widget**.

### From source

```bash
make app
open "dist/Mole Widget.app"   # or move it to /Applications
```

## Uninstall

1. Toggle off **Launch at login** in the menu bar (if you enabled it) and quit the widget
2. Remove the package:

```bash
brew uninstall mole-mac-widget
```

3. Optional cleanup — remove the tap and the saved settings:

```bash
brew untap bsnkhua/tap
defaults delete com.sbezbabnykh.mole-widget
```

> Uninstalled while the widget was still running? The orphaned process keeps
> the widget on screen — quit it with:
>
> ```bash
> pkill -f "Mole Widget"
> ```

## Development

```bash
make run    # run a dev build
make test   # run the test suite (32 tests)
```

> **Important:** run tests only via `make test`. On a machine without full Xcode
> a bare `swift test` silently runs zero tests and exits 0 — the Makefile passes
> the toolchain flags required for Swift Testing from Command Line Tools.

## Architecture

```
Sources/MoleWidgetCore/    — library
  CPU|Memory|Disk|Power/   — one module per domain: pure math + collector
  Store/MetricsStore.swift — @Observable store, 2/30/60 s timers
  Views/                   — SwiftUI, terminal theme
Sources/MoleWidget/        — app shell: desktop-level window, MenuBarExtra
```

All computation is pure functions over raw snapshots (unit-tested); collectors are thin wrappers around mach APIs / IOKit with smoke tests.
