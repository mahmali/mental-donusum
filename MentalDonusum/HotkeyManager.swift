import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    static let shared = HotkeyManager()

    static let keyCodeKey = "MentalDonusum.HotkeyKeyCode"
    static let modifiersKey = "MentalDonusum.HotkeyModifiers"
    static let defaultKeyCode: UInt16 = UInt16(kVK_ANSI_T)
    static let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    private init() {}

    static var storedKeyCode: UInt16 {
        if let v = UserDefaults.standard.object(forKey: keyCodeKey) as? Int {
            return UInt16(v)
        }
        return defaultKeyCode
    }

    static var storedModifiers: NSEvent.ModifierFlags {
        if let v = UserDefaults.standard.object(forKey: modifiersKey) as? Int {
            return NSEvent.ModifierFlags(rawValue: UInt(v))
        }
        return defaultModifiers
    }

    static func save(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(modifiers.rawValue), forKey: modifiersKey)
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
    }

    /// Saved kısayolu uygular, dinleyici handler'ı tutar.
    func register(handler: @escaping () -> Void) {
        self.handler = handler
        reapply()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reapply),
            name: .hotkeyChanged, object: nil
        )
    }

    @objc func reapply() {
        unregisterHotkey()
        installHandlerIfNeeded()

        let keyCode = HotkeyManager.storedKeyCode
        let carbonMods = Self.carbonModifiers(from: HotkeyManager.storedModifiers)
        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)

        let regStatus = RegisterEventHotKey(
            UInt32(keyCode), carbonMods, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )

        if regStatus != noErr {
            NSLog("HotkeyManager: RegisterEventHotKey failed: \(regStatus)")
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr, hkID.signature == HotkeyManager.signature else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.handler?() }
                return noErr
            },
            1, &eventType, userData, &eventHandlerRef
        )
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift)   { result |= UInt32(shiftKey) }
        if flags.contains(.option)  { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private static let signature: OSType = {
        let chars: [UInt8] = [0x4D, 0x44, 0x4E, 0x53] // 'MDNS'
        return chars.reduce(0) { ($0 << 8) | OSType($1) }
    }()
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("MentalDonusum.HotkeyChanged")
}
