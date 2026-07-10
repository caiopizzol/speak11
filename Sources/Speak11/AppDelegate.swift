import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let selectionReader = SelectionReader()
    private let speechController = SpeechController()
    private let hotKeyMonitor = HotKeyMonitor()
    private var statusMenuController: StatusMenuController?
    private var onboardingWindowController: OnboardingWindowController?
    private var accessibilityTimer: Timer?
    private var selectionTask: Task<Void, Never>?
    private var selectionGeneration = 0
    private var isOnboardingActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController(
            speechController: speechController,
            onReadSelection: { [weak self] in self?.readSelection() }
        )

        hotKeyMonitor.onPress = { [weak self] in
            self?.readSelection()
        }

        speechController.onStateChange = { [weak self] _ in
            self?.statusMenuController?.refreshIcon()
        }

        startHotKey()
        routeLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        onboardingWindowController?.cancel()
        accessibilityTimer?.invalidate()
        selectionTask?.cancel()
        hotKeyMonitor.stop()
        speechController.stop()
    }

    private func readSelection() {
        guard !isOnboardingActive else {
            NSSound.beep()
            return
        }

        if speechController.isUserInitiatedActive {
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

    private func routeLaunch() {
        let onboardingCompleted = Preferences.onboardingCompleted
        let modelsAvailable = onboardingCompleted
            ? SpeechController.modelsAvailableOnDisk()
            : false

        switch OnboardingLaunchDecision.decide(
            onboardingCompleted: onboardingCompleted,
            modelsAvailable: modelsAvailable
        ) {
        case .firstRun:
            showOnboarding(flow: .firstRun)
        case .modelRecovery:
            showOnboarding(flow: .modelRecovery)
        case .normal:
            requestAccessibilityPermissionIfNeeded()
            speechController.warmUpVoice()
        }
    }

    private func showOnboarding(flow: OnboardingFlow) {
        isOnboardingActive = true
        let controller = OnboardingWindowController(
            flow: flow,
            speechController: speechController,
            onCompletion: { [weak self] completion in
                self?.finishOnboarding(completion)
            }
        )
        onboardingWindowController = controller
        controller.show()
    }

    private func finishOnboarding(_ completion: OnboardingWindowController.Completion) {
        switch completion {
        case .completedFirstRun:
            Preferences.onboardingCompleted = true
        case .completedRecovery:
            break
        }

        isOnboardingActive = false
        onboardingWindowController = nil
        requestAccessibilityPermissionIfNeeded()
        statusMenuController?.refreshIcon()
    }

    private func startHotKey() {
        _ = hotKeyMonitor.start()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !SelectionReader.isAccessibilityEnabled else { return }
        SelectionReader.requestAccessibilityPermission()
        startAccessibilityPolling()
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
        statusMenuController?.refreshIcon()
    }
}
