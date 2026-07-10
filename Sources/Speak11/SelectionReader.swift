import AppKit
import ApplicationServices

@MainActor
final class SelectionReader {
    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt"
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

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        if let text = await copiedSelection(pasteboard: pasteboard, snapshot: snapshot) {
            return TextNormalizer.normalize(text)
        }

        // Terminals and tmux often place a selection straight on the
        // clipboard without exposing it through Accessibility. The fallback
        // speaks the snapshot captured when the shortcut was pressed, not
        // whatever is on the live clipboard after the Command-C wait.
        guard let clipboardText = Self.clipboardFallback(
            isEnabled: Preferences.readsClipboardWhenNothingSelected,
            snapshot: snapshot
        ) else { return nil }
        return TextNormalizer.normalize(clipboardText)
    }

    static func clipboardFallback(
        isEnabled: Bool,
        snapshot: PasteboardSnapshot
    ) -> String? {
        guard isEnabled else { return nil }
        return snapshot.plainText
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

    private func copiedSelection(
        pasteboard: NSPasteboard,
        snapshot: PasteboardSnapshot
    ) async -> String? {
        guard !snapshot.containsSensitiveData else { return nil }
        let originalChangeCount = pasteboard.changeCount

        postCopyShortcut()

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(25))
            guard pasteboard.changeCount != originalChangeCount else { continue }

            // Snapshotting the post-copy state applies the same sensitive-type
            // guard to whatever landed on the pasteboard. A concurrent write by
            // another process is indistinguishable from the Command-C result;
            // that ambiguity is inherent to this compatibility fallback.
            let copiedChangeCount = pasteboard.changeCount
            let copied = PasteboardSnapshot(pasteboard: pasteboard)
            if pasteboard.changeCount == copiedChangeCount {
                snapshot.restore(to: pasteboard)
            }
            guard !Task.isCancelled else { return nil }
            return copied.plainText
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
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

private enum AccessibilitySelection {
    case text(String)
    case secureField
    case unavailable
}
