import AppKit
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speechController: SpeechController
    private let onReadSelection: () -> Void

    init(
        speechController: SpeechController,
        onReadSelection: @escaping () -> Void
    ) {
        self.speechController = speechController
        self.onReadSelection = onReadSelection
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

        if !SelectionReader.isAccessibilityEnabled {
            menu.addItem(item(
                "Allow Accessibility Access…",
                action: #selector(openAccessibilitySettings)
            ))
            addLaunchAndQuitItems(to: menu)
            return
        }

        switch speechController.state {
        case .idle:
            menu.addItem(item("Read Selection    ⌥⇧/", action: #selector(readSelection)))
        case .preparing:
            let preparingItem = item("Preparing Voice…", action: nil)
            preparingItem.isEnabled = false
            menu.addItem(preparingItem)
        case .speaking:
            menu.addItem(item("Stop Speaking    ⌥⇧/", action: #selector(readSelection)))
        case let .failed(failure):
            menu.addItem(item(
                "⚠︎ Couldn't Speak — Try Again",
                action: #selector(retrySpeech)
            ))
            let summaryItem = item(failure.menuSummary, action: nil)
            summaryItem.isEnabled = false
            menu.addItem(summaryItem)
        }

        let speedItem = NSMenuItem(
            title: "Speed: \(formattedSpeed(Preferences.speakingRate))×",
            action: nil,
            keyEquivalent: ""
        )
        speedItem.submenu = speedMenu()
        menu.addItem(speedItem)

        addLaunchAndQuitItems(to: menu)
    }

    private func addLaunchAndQuitItems(to menu: NSMenu) {
        menu.addItem(.separator())
        let loginItem = item("Launch at Login", action: #selector(toggleLaunchAtLogin))
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(item("Quit Speak11", action: #selector(quit)))
    }

    private func speedMenu() -> NSMenu {
        let menu = NSMenu()
        for speed: Float in [0.75, 1, 1.25, 1.5, 1.75, 2] {
            let speedItem = item(
                "\(formattedSpeed(speed))×",
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

    @objc private func retrySpeech() {
        speechController.retry()
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func formattedSpeed(_ speed: Float) -> String {
        let text = String(format: "%.2f", speed)
        return text
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}

private extension NSMenuItem {
    func withTarget(_ target: AnyObject) -> Self {
        self.target = target
        return self
    }
}
