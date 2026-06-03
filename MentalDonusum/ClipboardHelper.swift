import AppKit
import ApplicationServices

/// Hotkey basıldığında ön plandaki uygulamadan seçili metni almak için
/// ⌘C simülasyonu yapar. Bunun çalışması için Accessibility izni gerekir.
enum ClipboardHelper {

    struct GrabResult {
        let text: String?
        let hasAccessibility: Bool
        /// `true` ise pano taze (kopyalama başarılı), aksi halde mevcut pano değişmedi.
        let copiedFreshSelection: Bool
    }

    /// Ön plandaki uygulamadan seçimi ⌘C ile kopyalar, panoyu döndürür.
    /// Pencere aktive edilmeden önce çağrılmalı — yoksa Cmd+C bizim uygulamaya gider.
    static func grabSelectionAndReadClipboard() async -> GrabResult {
        let hasAccessibility = isAccessibilityGranted(prompt: false)
        let pasteboard = NSPasteboard.general
        let priorChangeCount = pasteboard.changeCount

        if hasAccessibility {
            sendCommandC()
            // Pano güncellemesini bekle — kısa bir uyku yeterli
            try? await Task.sleep(nanoseconds: 130_000_000) // 130 ms
        }

        let copied = pasteboard.changeCount > priorChangeCount
        let text = pasteboard.string(forType: .string)

        return GrabResult(
            text: text,
            hasAccessibility: hasAccessibility,
            copiedFreshSelection: copied
        )
    }

    /// İzin kontrolü. `prompt: true` verilirse sistem diyaloğu açar (uygulama başına bir kez).
    @discardableResult
    static func isAccessibilityGranted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let opts: [String: Bool] = [key: prompt]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    /// Sistem Ayarları → Gizlilik & Güvenlik → Erişilebilirlik bölümünü açar.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private static let virtualKeyC: CGKeyCode = 0x08  // kVK_ANSI_C

    private static func sendCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyC, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyC, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}

extension Notification.Name {
    /// Hotkey ile seçim alındığında metin gönderilir; userInfo["text"] -> String
    static let translateText = Notification.Name("MentalDonusum.TranslateText")
    /// Accessibility izni gerektiğinde gönderilir.
    static let accessibilityNeeded = Notification.Name("MentalDonusum.AccessibilityNeeded")
}
