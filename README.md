# Bitcoin Block Clock (v2 — Swift/macOS)

Cross-platform-ready screensaver displaying current Bitcoin block height, timestamp, and local time via [mempool.space](https://mempool.space) WebSocket API.

Ported from the original macOS `.saver` bundle (Cocoa/WebView) to a standalone `.app` using Swift + WKWebView. The web layer (HTML/CSS/JS) is fully self-contained and portable to Linux (WebKitGTK) or Qt (QWebEngineView) wrappers.

![screenshot](screenshot.png)

## Requirements

- macOS 12 Monterey or later
- Swift 5.9+ (included with Xcode 15+ or Xcode Command Line Tools)
- Internet connection (WebSocket to mempool.space)

## Build

```bash
# Release .app bundle
./build.sh

# Debug build + run windowed
./build.sh run

# Debug build + run fullscreen (move mouse to exit)
./build.sh run-full

# Build release + install as screensaver daemon
./build.sh install

# Remove app + daemon
./build.sh uninstall

# Clean
./build.sh clean
```

Output: `build/Bitcoin Block Clock.app`

## IDE

Open `BitcoinBlockClock.code-workspace` in VS Code. Build tasks are pre-configured (Cmd+Shift+B).

For the Swift VS Code extension: install [Swift](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode) by Swift Lang.

## Install as Screensaver

Since macOS no longer supports `.saver` bundles with web content, this runs as a background daemon that monitors system idle time via IOKit and shows fullscreen windows when the threshold is reached.

```bash
# Build, install to /Applications, and start the daemon
./build.sh install

# Remove app and daemon
./build.sh uninstall
```

This installs a LaunchAgent (`~/Library/LaunchAgents/com.bitcoinblockclock.plist`) that starts the app at login in daemon mode. The app sits invisibly in the background, polls idle time every 5 seconds, and goes fullscreen when the idle threshold is reached. Any mouse/keyboard input dismisses it.

Default settings (edit at the top of `build.sh`, then re-run `./build.sh install`):

| Setting | Default | Description |
|---|---|---|
| `IDLE_SECONDS` | `300` | Seconds of inactivity before showing (5 minutes) |
| `TIMEZONE` | `city` | Timezone display: `city`, `abbrev`, or `disable` |
| `SCREEN_MODE` | `all-screens` | Display target: `all-screens`, `primary`, or `screen=N` |

Logs: `/tmp/bitcoinblockclock.log`

## Command-line Options

| Flag | Description |
|---|---|
| `--daemon` | Run as background daemon (monitor idle time, show/hide automatically) |
| `--idle=N` | Idle threshold in seconds (default 300, minimum 10) |
| `--windowed` | Run in a resizable window (debug mode) |
| `--timezone=city` | Show timezone as city name (e.g. "Asia / Hong Kong") |
| `--timezone=abbrev` | Show timezone abbreviation (e.g. "HKT") |
| `--timezone=disable` | Hide timezone (default) |
| `--screen=N` | Target screen by index (0 = primary) |
| `--all-screens` | Show on all connected displays |

## Architecture

```
BitcoinBlockClock-Swift/
├── build.sh                          # Build + bundle + run
├── Package.swift                     # SPM manifest
├── BitcoinBlockClock.code-workspace  # VS Code workspace
├── BitcoinBlockClock/
│   ├── BitcoinBlockClockApp.swift    # @main entry point
│   └── AppDelegate.swift             # Window management, WKWebView, config
└── Webview/                          # ★ Portable web layer ★
    ├── index.html                    # Reads config from URL query params
    ├── index.css                     # GeoSans Light font, layout
    ├── index.js                      # mempool.space API, WebSocket, clock
    └── font/
        └── geosanslight_v3-webfont.woff2
```

The **Webview/** directory is the cross-platform core. It works identically when loaded by:
- **WKWebView** (this Swift app)
- **QWebEngineView** (Qt/C++ wrapper for Linux/macOS)
- **WebKitGTK** (Linux XScreenSaver integration)
- **Any browser** (standalone web page)

Config is passed via URL query parameters (`?timezone=timeZoneCity&screensaver=1`), not injected JS variables, so every wrapper loads it the same way.

## Linux Port Path

For XScreenSaver on Linux, the wrapper would be ~80 lines of C or Python:

```c
// Pseudocode — GTK4 + WebKitGTK
GtkWidget *window = gtk_window_new();
WebKitWebView *web = webkit_web_view_new();
webkit_web_view_load_uri(web, "file:///path/to/Webview/index.html?...");
// Set fullscreen, connect to xscreensaver window-id, etc.
```

## Credits

- Original Bitcoin Block Clock: [@disuye](https://twitter.com/disuye)
- WebView scaffold based on [word-clock-screensaver](https://github.com/chrstphrknwtn/word-clock-screensaver) by Christopher Newton
- Font: [GeoSans Light](https://www.dafont.com/geo-sans-light.font) by Manfred Klein
- API: [mempool.space](https://mempool.space)
