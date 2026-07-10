import Carbon
import Foundation

private let speakHotKeySignature: OSType = 0x5350_3131
private let speakHotKeyID: UInt32 = 1
private let speakHotKeyModifiers = UInt32(optionKey)

private let speakHotKeyHandler: EventHandlerUPP = { _, event, context in
    guard let event, let context else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard
        status == noErr,
        hotKeyID.signature == speakHotKeySignature,
        hotKeyID.id == speakHotKeyID
    else {
        return noErr
    }

    let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in monitor.fire() }
    return noErr
}

enum SpeakKeyCodeResolver {
    static let speakKeyCharacter: Character = "a"
    static let fallbackKeyCode: UInt32 = UInt32(kVK_ANSI_A)

    static func keyCode(
        for character: Character,
        translate: (UInt16) -> Character?
    ) -> UInt32? {
        for keyCode in UInt16(0)...UInt16(127) {
            if translate(keyCode) == character {
                return UInt32(keyCode)
            }
        }
        return nil
    }

    static func activeLayoutSpeakKeyCode() -> UInt32 {
        guard
            let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutDataPointer = TISGetInputSourceProperty(
                inputSource,
                kTISPropertyUnicodeKeyLayoutData
            )
        else {
            return fallbackKeyCode
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        return keyCode(for: speakKeyCharacter) { keyCode in
            character(for: keyCode, layoutData: layoutData)
        } ?? fallbackKeyCode
    }

    private static func character(for keyCode: UInt16, layoutData: CFData) -> Character? {
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }

        var deadKeyState: UInt32 = 0
        var actualLength = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { keyboardLayout in
            UCKeyTranslate(
                keyboardLayout,
                keyCode,
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                characters.count,
                &actualLength,
                &characters
            )
        }
        guard status == noErr, actualLength == 1 else { return nil }
        return Character(String(utf16CodeUnits: characters, count: Int(actualLength)))
    }
}

@MainActor
final class HotKeyMonitor {
    var onPress: (() -> Void)?
    var onRegistrationChange: ((Bool) -> Void)?

    private(set) var isRegistered = false {
        didSet {
            if isRegistered != oldValue {
                onRegistrationChange?(isRegistered)
            }
        }
    }

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var layoutChangeObserver: NSObjectProtocol?

    @discardableResult
    func start() -> Bool {
        guard eventHotKey == nil else { return true }

        guard installHandler() else { return false }
        registerLayoutChangeObserver()
        return registerHotKey()
    }

    func stop() {
        if let layoutChangeObserver {
            DistributedNotificationCenter.default().removeObserver(layoutChangeObserver)
        }
        layoutChangeObserver = nil
        unregisterHotKey()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    func fire() {
        onPress?()
    }

    private func installHandler() -> Bool {
        guard eventHandler == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            speakHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard status == noErr else { return false }
        eventHandler = handler
        return true
    }

    private func registerLayoutChangeObserver() {
        guard layoutChangeObserver == nil else { return }
        guard let name = kTISNotifySelectedKeyboardInputSourceChanged else { return }

        layoutChangeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(name as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reregisterHotKey()
            }
        }
    }

    private func registerHotKey() -> Bool {
        unregisterHotKey()
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: speakHotKeySignature, id: speakHotKeyID)
        let status = RegisterEventHotKey(
            SpeakKeyCodeResolver.activeLayoutSpeakKeyCode(),
            speakHotKeyModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            isRegistered = false
            return false
        }
        eventHotKey = hotKeyRef
        isRegistered = true
        return true
    }

    private func reregisterHotKey() {
        _ = registerHotKey()
    }

    private func unregisterHotKey() {
        if let eventHotKey {
            UnregisterEventHotKey(eventHotKey)
        }
        eventHotKey = nil
        isRegistered = false
    }
}
