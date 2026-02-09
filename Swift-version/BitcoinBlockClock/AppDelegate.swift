import AppKit
import WebKit

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var windows: [ScreenSaverWindow] = []
    private var config = ScreenSaverConfig.fromCommandLine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let htmlURL = locateHTML() else {
            print("ERROR: Cannot find Webview/index.html")
            print("Searched relative to: \(executableDir().path)")
            NSApp.terminate(nil)
            return
        }

        let screens = config.windowed ? [NSScreen.main!] : targetScreens()

        for screen in screens {
            let window = ScreenSaverWindow(
                htmlURL: htmlURL,
                config: config,
                screen: screen
            )
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Locate HTML

    private func executableDir() -> URL {
        return URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
    }

    private func locateHTML() -> URL? {
        let exe = executableDir()
        let candidates = [
            // .app bundle: Contents/MacOS/../Resources/Webview/index.html
            exe.appendingPathComponent("../Resources/Webview/index.html").standardized,
            // Dev: run from project root (e.g. `swift run` or direct execution)
            URL(fileURLWithPath: "Webview/index.html"),
            // Dev: Webview next to binary
            exe.appendingPathComponent("Webview/index.html"),
            // Fallback: cwd
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Webview/index.html"),
        ]

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    // MARK: - Screen targeting

    private func targetScreens() -> [NSScreen] {
        let all = NSScreen.screens
        guard !all.isEmpty else { return [] }

        switch config.screenMode {
        case .primary:
            return [all[0]]
        case .allScreens:
            return all
        case .specific(let idx):
            let i = min(idx, all.count - 1)
            return [all[i]]
        }
    }
}


// MARK: - Configuration

struct ScreenSaverConfig {
    var windowed: Bool = false
    var timezone: String = "timeZoneDisable"
    var screenMode: ScreenMode = .primary

    enum ScreenMode {
        case primary
        case allScreens
        case specific(Int)
    }

    static func fromCommandLine() -> ScreenSaverConfig {
        var config = ScreenSaverConfig()

        for arg in CommandLine.arguments {
            if arg == "--windowed" {
                config.windowed = true
            }
            else if arg.hasPrefix("--timezone=") {
                let val = String(arg.dropFirst("--timezone=".count))
                switch val {
                case "city":    config.timezone = "timeZoneCity"
                case "abbrev":  config.timezone = "timeZoneAbbrv"
                case "disable": config.timezone = "timeZoneDisable"
                default:        config.timezone = val
                }
            }
            else if arg == "--all-screens" {
                config.screenMode = .allScreens
            }
            else if arg.hasPrefix("--screen=") {
                if let idx = Int(String(arg.dropFirst("--screen=".count))) {
                    config.screenMode = .specific(idx)
                }
            }
        }
        return config
    }
}


// MARK: - ScreenSaverWindow
// Uses composition (owns an NSWindow) rather than subclassing,
// which avoids NSWindow designated initializer pitfalls.

class ScreenSaverWindow: NSObject {

    let window: NSWindow
    private var webView: WKWebView!
    private let isWindowed: Bool
    private var mouseMoveCount = 0
    private var eventMonitors: [Any] = []

    init(htmlURL: URL, config: ScreenSaverConfig, screen: NSScreen) {
        self.isWindowed = config.windowed

        let frame = config.windowed
            ? NSRect(x: 0, y: 0, width: 960, height: 540)
            : screen.frame

        let styleMask: NSWindow.StyleMask = config.windowed
            ? [.titled, .closable, .resizable]
            : [.borderless]

        window = NSWindow(
            contentRect: frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        super.init()

        if !config.windowed {
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isOpaque = true
            window.hidesOnDeactivate = false
            window.acceptsMouseMovedEvents = true
        }

        window.backgroundColor = .black
        window.title = "Bitcoin Block Clock"

        // ── WKWebView ──

        let webConfig = WKWebViewConfiguration()
        webConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = container

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // ── Load HTML with query params ──

        let baseDir = htmlURL.deletingLastPathComponent()
        var components = URLComponents(url: htmlURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "screensaver", value: "1"),
            URLQueryItem(name: "timezone", value: config.timezone),
        ]
        if config.windowed {
            components.queryItems?.append(URLQueryItem(name: "is_preview", value: "1"))
        }

        webView.loadFileURL(components.url!, allowingReadAccessTo: baseDir)

        // ── Input handling via event monitors ──

        installEventMonitors()

        // ── Show ──

        if config.windowed {
            window.center()
            window.makeKeyAndOrderFront(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSCursor.hide()
            }
        }
    }

    deinit {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Event monitors (screensaver exit behavior)

    private func installEventMonitors() {
        // Local monitors catch events directed at our window

        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.isWindowed {
                if event.keyCode == 53 { NSApp.terminate(nil) }  // Esc
                return event
            } else {
                NSCursor.unhide()
                NSApp.terminate(nil)
                return nil
            }
        }
        if let m = keyMonitor { eventMonitors.append(m) }

        let clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if !self.isWindowed {
                NSCursor.unhide()
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
        if let m = clickMonitor { eventMonitors.append(m) }

        let moveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return event }
            if !self.isWindowed {
                self.mouseMoveCount += 1
                if self.mouseMoveCount > 5 {
                    NSCursor.unhide()
                    NSApp.terminate(nil)
                    return nil
                }
            }
            return event
        }
        if let m = moveMonitor { eventMonitors.append(m) }

        let scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            if !self.isWindowed {
                NSCursor.unhide()
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
        if let m = scrollMonitor { eventMonitors.append(m) }
    }
}
