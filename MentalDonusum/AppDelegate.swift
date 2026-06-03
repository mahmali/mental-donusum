import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let storedTheme = UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? AppTheme.system.rawValue
        AppTheme.apply(rawValue: storedTheme)

        buildMainWindow()
        showMainWindow()

        HotkeyManager.shared.register { [weak self] in
            guard let self else { return }
            self.showMainWindow()
            NotificationCenter.default.post(name: .translateFromClipboard, object: nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showMainWindow() }
        return true
    }

    func showMainWindow() {
        if mainWindow == nil { buildMainWindow() }
        guard let window = mainWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildMainWindow() {
        let hosting = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Mental Dönüşüm"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.setContentSize(NSSize(width: 820, height: 500))
        window.minSize = NSSize(width: 640, height: 360)
        window.center()
        window.setFrameAutosaveName("MentalDonusumMainWindow")
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        mainWindow = window
    }
}
