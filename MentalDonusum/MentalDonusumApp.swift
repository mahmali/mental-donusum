import SwiftUI
import AppKit

@main
struct MentalDonusumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appDelegate)
        } label: {
            Image(systemName: "character.bubble.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        Button("Çevirmeni Aç  ⌘⇧T") {
            appDelegate.showMainWindow()
        }

        Button("Panodaki Metni Çevir") {
            appDelegate.showMainWindow()
            NotificationCenter.default.post(name: .translateFromClipboard, object: nil)
        }

        Divider()

        Button("Mental Dönüşüm Hakkında") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        Divider()

        Button("Çıkış") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension Notification.Name {
    static let translateFromClipboard = Notification.Name("MentalDonusum.TranslateFromClipboard")
}
