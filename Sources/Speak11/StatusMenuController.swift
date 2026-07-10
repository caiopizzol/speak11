import AppKit
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speechController: SpeechController
    private let onReadSelection: () -> Void
    private let onPrepareVoice: () -> Void

    init(
        speechController: SpeechController,
        onReadSelection: @escaping () -> Void,
        onPrepareVoice: @escaping () -> Void
    ) {
        self.speechController = speechController
        self.onReadSelection = onReadSelection
        self.onPrepareVoice = onPrepareVoice
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    func refreshIcon() {
        let symbol: String
        switch speechController.state {
        case .idle, .failed:
            symbol = "waveform"
        case .preparing:
            symbol = "ellipsis.circle"
        case .speaking:
            symbol = "waveform.circle.fill"
        }
        statusItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: "Speak11"
        )
        statusItem.button?.toolTip = "Speak11"
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let readTitle = speechController.isActive
            ? "Stop Speaking"
            : "Read Selection    ⌥⇧/"
        menu.addItem(item(readTitle, action: #selector(readSelection)))
        menu.addItem(.separator())

        let voiceStatus: String
        if speechController.isVoicePrepared {
            voiceStatus = "Kokoro Heart Ready"
        } else if speechController.state == .preparing {
            voiceStatus = "Preparing Kokoro Voice…"
        } else {
            voiceStatus = "Prepare Kokoro Voice…"
        }
        let voiceItem = item(voiceStatus, action: #selector(prepareVoice))
        voiceItem.isEnabled = !speechController.isVoicePrepared && !speechController.isActive
        menu.addItem(voiceItem)

        let speedItem = NSMenuItem(title: "Speaking Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu()
        menu.addItem(speedItem)

        let loginItem = item("Launch at Login", action: #selector(toggleLaunchAtLogin))
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        if !SelectionReader.isAccessibilityEnabled {
            menu.addItem(.separator())
            menu.addItem(item(
                "Allow Accessibility Access…",
                action: #selector(openAccessibilitySettings)
            ))
        }

        if case let .failed(message) = speechController.state {
            menu.addItem(.separator())
            let errorItem = item("Show Speech Error…", action: #selector(showSpeechError(_:)))
            errorItem.representedObject = message
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())
        menu.addItem(item("Quit Speak11", action: #selector(quit)))
    }

    private func speedMenu() -> NSMenu {
        let menu = NSMenu()
        for speed: Float in [0.75, 1, 1.25, 1.5, 1.75, 2] {
            let speedItem = item(
                speed == 1 ? "Normal" : "\(speed.formatted())×",
                action: #selector(selectSpeed(_:))
            )
            speedItem.representedObject = NSNumber(value: speed)
            speedItem.state = abs(Preferences.speakingRate - speed) < 0.001 ? .on : .off
            menu.addItem(speedItem)
        }
        return menu
    }

    private func item(_ title: String, action: Selector?) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "").withTarget(self)
    }

    @objc private func readSelection() {
        onReadSelection()
    }

    @objc private func prepareVoice() {
        onPrepareVoice()
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        Preferences.speakingRate = number.floatValue
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Launch at Login Could Not Be Changed"
            alert.runModal()
        }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func showSpeechError(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Speak11 Could Not Generate Speech"
        alert.informativeText = sender.representedObject as? String ?? "An unknown error occurred."
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension NSMenuItem {
    func withTarget(_ target: AnyObject) -> Self {
        self.target = target
        return self
    }
}
