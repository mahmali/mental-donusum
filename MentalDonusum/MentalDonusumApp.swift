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
            Image(systemName: "translate")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue

    var body: some View {
        Button("Çevirmeni Aç  ⌘⇧T") {
            appDelegate.showMainWindow()
        }

        Button("Panodaki Metni Çevir") {
            appDelegate.showMainWindow()
            NotificationCenter.default.post(name: .translateFromClipboard, object: nil)
        }

        Button("Geçmiş…") {
            appDelegate.showMainWindow()
            NotificationCenter.default.post(name: .openHistory, object: nil)
        }

        Divider()

        Button("Ayarlar…") {
            appDelegate.showMainWindow()
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }

        Menu("Tema") {
            Picker(selection: $themeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme.rawValue)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
            .labelsHidden()
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

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "MentalDonusum.AppTheme"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Aydınlık"
        case .dark: return "Karanlık"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static func apply(rawValue: String) {
        let theme = AppTheme(rawValue: rawValue) ?? .system
        NSApp.appearance = theme.nsAppearance
    }
}

extension Notification.Name {
    static let translateFromClipboard = Notification.Name("MentalDonusum.TranslateFromClipboard")
}
