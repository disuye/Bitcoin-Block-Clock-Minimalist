import AppKit
import WebKit
import IOKit

// MARK: - AppDelegate
//
// The app runs in two modes:
//
//   --windowed           Debug/preview mode (shows immediately, no idle watch)
//   --daemon             Background daemon mode (watches idle time, auto-shows)
//   (neither)            Immediate fullscreen mode (legacy behavior, shows now and quits on input)
//

class AppDelegate: NSObject, NSApplicationDelegate {

    private var windows: [ScreenSaverWindow] = []
    private var config = ScreenSaverConfig.fromCommandLine()
    private var idleTimer: Timer?
    private var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard locateHTML() != nil else {
            print("ERROR: Cannot find Webview/index.html")
            print("Searched relative to: \(executableDir().path)")
            NSApp.terminate(nil)
            return
        }

        if config.daemon {
            // Daemon mode: sit in background, poll idle time
            print("Bitcoin Block Clock daemon started (idle threshold: \(config.idleSeconds)s)")
            fflush(stdout)
            startIdleWatch()
        } else {
            // Immediate mode: show now
            showScreenSaver()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        idleTimer?.invalidate()
    }

    // MARK: - Idle Time Monitoring

    private func startIdleWatch() {
        // Poll every 5 seconds — lightweight, uses IOKit HIDSystem idle time
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let idle = self.systemIdleTime()

            if !self.isShowing && idle >= Double(self.config.idleSeconds) {
                self.showScreenSaver()
            }
        }
    }

    /// Returns system idle time in seconds via IOKit (same source macOS uses internally)
    private func systemIdleTime() -> Double {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleObj = dict["HIDIdleTime"] as? NSNumber else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return idleObj.doubleValue / 1_000_000_000.0
    }

    // MARK: - Show / Dismiss

    private func showScreenSaver() {
        guard !isShowing else { return }
        guard let htmlURL = locateHTML() else { return }
        isShowing = true

        let screens = config.windowed ? [NSScreen.main!] : targetScreens()

        for screen in screens {
            let window = ScreenSaverWindow(
                htmlURL: htmlURL,
                config: config,
                screen: screen,
                onDismiss: { [weak self] in
                    self?.dismissScreenSaver()
                }
            )
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissScreenSaver() {
        NSCursor.unhide()

        for w in windows {
            w.window.orderOut(nil)
        }
        windows.removeAll()
        isShowing = false

        if !config.daemon {
            // One-shot mode: quit after dismissal
            NSApp.terminate(nil)
        }
        // Daemon mode: keep running, will re-show when idle again
    }

    // MARK: - Locate HTML

    private func executableDir() -> URL {
        return URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
    }

    private func locateHTML() -> URL? {
        let exe = executableDir()
        let candidates = [
            exe.appendingPathComponent("../Resources/Webview/index.html").standardized,
            URL(fileURLWithPath: "Webview/index.html"),
            exe.appendingPathComponent("Webview/index.html"),
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
    var daemon: Bool = false
    var idleSeconds: Int = 300  // 5 minutes default
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
            else if arg == "--daemon" {
                config.daemon = true
            }
            else if arg.hasPrefix("--idle=") {
                if let secs = Int(String(arg.dropFirst("--idle=".count))) {
                    config.idleSeconds = max(10, secs)
                }
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

class ScreenSaverWindow: NSObject {

    let window: NSWindow
    private var webView: WKWebView!
    private let isWindowed: Bool
    private var mouseMoveCount = 0
    private var eventMonitors: [Any] = []
    private var onDismiss: (() -> Void)?

    init(htmlURL: URL, config: ScreenSaverConfig, screen: NSScreen, onDismiss: @escaping () -> Void) {
        self.isWindowed = config.windowed
        self.onDismiss = onDismiss

        let styleMask: NSWindow.StyleMask = config.windowed
            ? [.titled, .closable, .resizable]
            : [.borderless]

        // For borderless fullscreen, create at a dummy rect first,
        // then setFrame to the exact screen frame in global coords.
        // NSWindow(contentRect:screen:) can misposition on secondary
        // displays because contentRect is interpreted relative to
        // the screen's coordinate space.
        let initialFrame = config.windowed
            ? NSRect(x: 0, y: 0, width: 960, height: 540)
            : screen.frame

        window = NSWindow(
            contentRect: initialFrame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        super.init()

        if !config.windowed {
            // Force the window to exactly cover this screen
            window.setFrame(screen.frame, display: true)
            window.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = true
            window.hidesOnDeactivate = false
            window.acceptsMouseMovedEvents = true
            window.canHide = false
        }

        window.backgroundColor = .black
        window.title = "Bitcoin Block Clock"

        // ── WKWebView ──

        let webConfig = WKWebViewConfiguration()
        webConfig.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        let container = NSView(frame: window.contentView?.bounds ?? window.frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.autoresizingMask = [.width, .height]
        window.contentView = container

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // ── Load HTML ──

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

        // ── Input handling ──

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

    // MARK: - Event monitors

    private func dismiss() {
        onDismiss?()
        onDismiss = nil  // prevent double-fire
    }

    private func installEventMonitors() {
        // Use global monitors so we catch events even when WKWebView has focus
        // (global monitors see events destined for any app)

        if !isWindowed {
            let globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                self?.dismiss()
            }
            if let m = globalKeyMonitor { eventMonitors.append(m) }

            let globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.dismiss()
            }
            if let m = globalClickMonitor { eventMonitors.append(m) }

            let globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                guard let self = self else { return }
                self.mouseMoveCount += 1
                if self.mouseMoveCount > 5 {
                    self.dismiss()
                }
            }
            if let m = globalMoveMonitor { eventMonitors.append(m) }

            let globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] _ in
                self?.dismiss()
            }
            if let m = globalScrollMonitor { eventMonitors.append(m) }
        }

        // Local monitors for events directed at our own windows

        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.isWindowed {
                if event.keyCode == 53 { self.dismiss() }
                return event
            } else {
                self.dismiss()
                return nil
            }
        }
        if let m = keyMonitor { eventMonitors.append(m) }

        let clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if !self.isWindowed {
                self.dismiss()
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
                    self.dismiss()
                    return nil
                }
            }
            return event
        }
        if let m = moveMonitor { eventMonitors.append(m) }

        let scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            if !self.isWindowed {
                self.dismiss()
                return nil
            }
            return event
        }
        if let m = scrollMonitor { eventMonitors.append(m) }
    }
}
