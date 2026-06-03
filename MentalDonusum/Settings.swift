import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keyCode: UInt16 = HotkeyManager.storedKeyCode
    @State private var modifiers: NSEvent.ModifierFlags = HotkeyManager.storedModifiers
    @State private var recording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ayarlar")
                    .font(.title2.bold())
                Spacer()
                Button("Bitti") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Global Kısayol")
                    .font(.headline)
                Text("Bu kısayola herhangi bir uygulamadayken bastığınızda Mental Dönüşüm pencerede pano metnini çevirir. En az bir komuta/seçenek/control tuşu içermelidir.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    HotkeyRecorderField(
                        keyCode: $keyCode,
                        modifiers: $modifiers,
                        isRecording: $recording
                    )
                    .frame(width: 220)

                    Button("Sıfırla") {
                        keyCode = HotkeyManager.defaultKeyCode
                        modifiers = HotkeyManager.defaultModifiers
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Text("Mental Dönüşüm · v1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(width: 500, height: 280)
        .onChange(of: keyCode) { _, _ in persist() }
        .onChange(of: modifiers) { _, _ in persist() }
    }

    private func persist() {
        HotkeyManager.save(keyCode: keyCode, modifiers: modifiers)
    }
}

struct HotkeyRecorderField: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    @Binding var isRecording: Bool
    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording { stopRecording() } else { startRecording() }
        } label: {
            HStack {
                if isRecording {
                    Text("Bir kombinasyona basın…")
                        .foregroundStyle(.tertiary)
                } else {
                    Text(ShortcutFormatter.string(keyCode: keyCode, modifiers: modifiers))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                Spacer()
                Image(systemName: isRecording ? "record.circle.fill" : "pencil")
                    .foregroundStyle(isRecording ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(isRecording ? 0.20 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isRecording ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let active = mods.intersection([.command, .option, .control, .shift])
            guard !active.isEmpty else {
                NSSound.beep()
                return nil
            }
            keyCode = event.keyCode
            modifiers = active
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        isRecording = false
    }
}

enum ShortcutFormatter {
    static func string(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    static func keyName(for code: UInt16) -> String {
        switch Int(code) {
        case kVK_ANSI_A: return "A"; case kVK_ANSI_B: return "B"; case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"; case kVK_ANSI_E: return "E"; case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"; case kVK_ANSI_H: return "H"; case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"; case kVK_ANSI_K: return "K"; case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"; case kVK_ANSI_N: return "N"; case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"; case kVK_ANSI_Q: return "Q"; case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"; case kVK_ANSI_T: return "T"; case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"; case kVK_ANSI_W: return "W"; case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"; case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"; case kVK_ANSI_1: return "1"; case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"; case kVK_ANSI_4: return "4"; case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"; case kVK_ANSI_7: return "7"; case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "␣"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"; case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"; case kVK_UpArrow: return "↑"
        case kVK_F1: return "F1"; case kVK_F2: return "F2"; case kVK_F3: return "F3"
        case kVK_F4: return "F4"; case kVK_F5: return "F5"; case kVK_F6: return "F6"
        case kVK_F7: return "F7"; case kVK_F8: return "F8"; case kVK_F9: return "F9"
        case kVK_F10: return "F10"; case kVK_F11: return "F11"; case kVK_F12: return "F12"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Grave: return "`"
        default: return "Key \(code)"
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("MentalDonusum.OpenSettings")
    static let openHistory = Notification.Name("MentalDonusum.OpenHistory")
}
