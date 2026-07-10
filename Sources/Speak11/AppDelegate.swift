import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let selectionReader = SelectionReader()
    private let speechController = SpeechController()
    private let hotKeyMonitor = HotKeyMonitor()
    private var statusMenuController: StatusMenuController?
    private var accessibilityTimer: Timer?
    private var selectionTask: Task<Void, Never>?
    private var selectionGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController(
            speechController: speechController,
            onReadSelection: { [weak self] in self?.readSelection() },
            onPrepareVoice: { [weak self] in self?.speechController.prepareVoice() }
        )

        hotKeyMonitor.onPress = { [weak self] in
            self?.readSelection()
        }

        speechController.onStateChange = { [weak self] _ in
            self?.statusMenuController?.refreshIcon()
        }

        requestAccessibilityAndStartHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        selectionTask?.cancel()
        hotKeyMonitor.stop()
        speechController.stop()
    }

    private func readSelection() {
        if speechController.isActive {
            speechController.stop()
            return
        }

        if selectionTask != nil {
            selectionGeneration += 1
            selectionTask?.cancel()
            selectionTask = nil
            return
        }

        selectionGeneration += 1
        let currentGeneration = selectionGeneration
        selectionTask = Task { [weak self] in
            guard let self else { return }
            let text = await selectionReader.readSelectedText()
            guard currentGeneration == selectionGeneration else { return }
            selectionTask = nil

            guard let text else {
                NSSound.beep()
                return
            }
            speechController.speak(text)
        }
    }

    private func requestAccessibilityAndStartHotKey() {
        guard SelectionReader.isAccessibilityEnabled else {
            SelectionReader.requestAccessibilityPermission()
            startAccessibilityPolling()
            return
        }
        _ = hotKeyMonitor.start()
    }

    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(checkAccessibilityPermission),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func checkAccessibilityPermission() {
        guard SelectionReader.isAccessibilityEnabled else { return }
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        _ = hotKeyMonitor.start()
        statusMenuController?.refreshIcon()
    }
}
