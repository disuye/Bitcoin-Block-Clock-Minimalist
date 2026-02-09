// Bitcoin Block Clock
// Cross-platform screensaver — Swift/macOS standalone .app
// Ported from Cocoa/WebView .saver bundle
// Original: github.com/disuye/Bitcoin-Block-Clock

import SwiftUI

@main
struct BitcoinBlockClockApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We manage windows manually via AppDelegate — no SwiftUI scenes needed.
        // This empty Settings scene satisfies the protocol requirement.
        Settings { EmptyView() }
    }
}
