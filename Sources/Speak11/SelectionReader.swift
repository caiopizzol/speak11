import AppKit
import ApplicationServices

@MainActor
final class SelectionReader {
    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func readSelectedText() async -> String? {
        switch accessibilitySelection() {
        case let .text(text):
            return TextNormalizer.normalize(text)
        case .secureField:
            return nil
        case .unavailable:
            break
        }

        guard Self.isAccessibilityEnabled else {
            Self.requestAccessibilityPermission()
            return nil
        }

        guard let text = await copiedSelection() else { return nil }
        return TextNormalizer.normalize(text)
    }

    private func accessibilitySelection() -> AccessibilitySelection {
        let system = AXUIElementCreateSystemWide()
        guard let focused = elementAttribute(kAXFocusedUIElementAttribute, from: system) else {
            return .unavailable
        }

        var current: AXUIElement? = focused
        for _ in 0..<5 {
            guard let element = current else { break }
            if isSecureTextField(element) {
                return .secureField
            }
            if let text = stringAttribute(kAXSelectedTextAttribute, from: element),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .text(text)
            }
            current = elementAttribute(kAXParentAttribute, from: element)
        }
        return .unavailable
    }

    private func copiedSelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        guard !snapshot.containsSensitiveData else { return nil }
        let originalChangeCount = pasteboard.changeCount

        postCopyShortcut()

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            guard pasteboard.changeCount != originalChangeCount else { continue }

            let copiedChangeCount = pasteboard.changeCount
            let text = pasteboard.string(forType: .string)
            if pasteboard.changeCount == copiedChangeCount {
                snapshot.restore(to: pasteboard)
            }
            guard !Task.isCancelled else { return nil }
            return text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? text
                : nil
        }
        return nil
    }

    private func postCopyShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func isSecureTextField(_ element: AXUIElement) -> Bool {
        stringAttribute(kAXSubroleAttribute, from: element)
            == (kAXSecureTextFieldSubrole as String)
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func elementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
}

private enum AccessibilitySelection {
    case text(String)
    case secureField
    case unavailable
}
