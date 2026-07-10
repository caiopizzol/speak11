import AppKit
import FluidAudio
import ServiceManagement

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    enum Completion {
        case completedFirstRun
        case completedRecovery
    }

    private let flow: OnboardingFlow
    private let speechController: SpeechController
    private let onCompletion: (Completion) -> Void
    private let window: NSWindow

    private var state: OnboardingState
    private var accessibilityTimer: Timer?
    private var downloadTask: Task<Void, Never>?
    private var didRequestAccessibility = false
    private var didFinish = false
    private var launchAtLoginCheckbox: NSButton?
    private var downloadProgressIndicator: NSProgressIndicator?
    private var downloadPhaseLabel: NSTextField?
    private var downloadPercentageLabel: NSTextField?

    init(
        flow: OnboardingFlow,
        speechController: SpeechController,
        onCompletion: @escaping (Completion) -> Void
    ) {
        self.flow = flow
        self.speechController = speechController
        self.onCompletion = onCompletion
        self.state = .initial(for: flow)
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        super.init()

        window.title = "Speak11"
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        render()
        window.center()
        window.makeKeyAndOrderFront(nil)
        enter(state.step)
    }

    func cancel() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        downloadTask?.cancel()
        downloadTask = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard didFinish else {
            cancel()
            NSApp.terminate(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        cancel()
        if didFinish {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func apply(_ event: OnboardingEvent) {
        guard !didFinish else { return }
        let previousKind = state.step.kind
        let transition = state.transitioning(event, flow: flow)
        state = transition.state

        switch transition.outcome {
        case .none:
            break
        case .finishRecovery:
            finish(.completedRecovery)
            return
        }

        if case let .downloading(progressFraction, phaseLabel) = state.step,
           previousKind == .downloading,
           let downloadProgressIndicator {
            downloadProgressIndicator.doubleValue = progressFraction
            downloadPhaseLabel?.stringValue = phaseLabel
            downloadPercentageLabel?.stringValue = percentageText(progressFraction)
            return
        }

        render()

        guard state.step.kind != previousKind else { return }
        enter(state.step)
    }

    private func enter(_ step: OnboardingStep) {
        switch step {
        case .accessibility:
            enterAccessibilityStep()
        case .downloading:
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
            startDownload()
        case .downloadFailed, .ready:
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
        }
    }

    private func enterAccessibilityStep() {
        guard !didRequestAccessibility else { return }
        didRequestAccessibility = true
        SelectionReader.requestAccessibilityPermission()

        guard !SelectionReader.isAccessibilityEnabled else {
            apply(.accessibilityGranted)
            return
        }

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
        apply(.accessibilityGranted)
    }

    private func startDownload() {
        downloadTask?.cancel()
        downloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await KokoroAneResourceDownloader.ensureModels(
                    variant: .english,
                    directory: nil,
                    progressHandler: { progress in
                        let fraction = progress.fractionCompleted
                        let phase = OnboardingDownloadPhase(progress.phase)
                        Task { @MainActor [weak self] in
                            self?.apply(.downloadProgress(
                                fraction: fraction,
                                phase: phase
                            ))
                        }
                    }
                )
                try Task.checkCancellation()
                try await speechController.prepareVoiceAndWait()
                try Task.checkCancellation()
                apply(.downloadSucceeded)
            } catch is CancellationError {
            } catch {
                apply(.downloadFailed(message: error.localizedDescription))
            }
            downloadTask = nil
        }
    }

    private func render() {
        launchAtLoginCheckbox = nil
        downloadProgressIndicator = nil
        downloadPhaseLabel = nil
        downloadPercentageLabel = nil

        let content = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -28),
        ])

        switch state.step {
        case .accessibility:
            renderAccessibilityStep(in: stack)
        case let .downloading(progressFraction, phaseLabel):
            renderDownloadStep(
                in: stack,
                progressFraction: progressFraction,
                phaseLabel: phaseLabel
            )
        case let .downloadFailed(message):
            renderDownloadFailedStep(in: stack, message: message)
        case .ready:
            renderReadyStep(in: stack)
        }

        window.contentView = content
    }

    private func renderAccessibilityStep(in stack: NSStackView) {
        stack.addArrangedSubview(titleLabel("Speak11"))
        stack.addArrangedSubview(bodyLabel(
            "Speak11 speaks the text you select in other apps. macOS requires your permission for that."
        ))

        let button = NSButton(
            title: "Open System Settings…",
            target: self,
            action: #selector(openAccessibilitySettings)
        )
        button.bezelStyle = .rounded
        stack.addArrangedSubview(button)
        stack.addArrangedSubview(secondaryLabel("Waiting for permission…"))
    }

    private func renderDownloadStep(
        in stack: NSStackView,
        progressFraction: Double,
        phaseLabel: String
    ) {
        stack.addArrangedSubview(titleLabel(downloadTitle))
        stack.addArrangedSubview(bodyLabel(downloadBody))

        let progress = NSProgressIndicator()
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = progressFraction
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.widthAnchor.constraint(equalToConstant: 356).isActive = true
        stack.addArrangedSubview(progress)

        let details = NSStackView()
        details.orientation = .horizontal
        details.alignment = .firstBaseline
        details.distribution = .fill
        details.spacing = 12
        details.translatesAutoresizingMaskIntoConstraints = false

        let phase = secondaryLabel(phaseLabel)
        let percentage = secondaryLabel(percentageText(progressFraction))
        percentage.alignment = .right
        percentage.setContentHuggingPriority(.required, for: .horizontal)
        details.addArrangedSubview(phase)
        details.addArrangedSubview(percentage)
        details.widthAnchor.constraint(equalToConstant: 356).isActive = true
        stack.addArrangedSubview(details)

        downloadProgressIndicator = progress
        downloadPhaseLabel = phase
        downloadPercentageLabel = percentage
    }

    private func percentageText(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private func renderDownloadFailedStep(in stack: NSStackView, message: String) {
        stack.addArrangedSubview(titleLabel("Couldn't Download the Voice"))
        stack.addArrangedSubview(bodyLabel(message))

        let button = NSButton(
            title: "Try Again",
            target: self,
            action: #selector(tryDownloadAgain)
        )
        button.bezelStyle = .rounded
        stack.addArrangedSubview(button)
    }

    private func renderReadyStep(in stack: NSStackView) {
        stack.addArrangedSubview(titleLabel("Select text anywhere, then press"))

        let keycap = NSTextField(labelWithString: "⌥A")
        keycap.alignment = .center
        keycap.font = .monospacedSystemFont(ofSize: 30, weight: .semibold)
        keycap.wantsLayer = true
        keycap.layer?.cornerRadius = 8
        keycap.layer?.borderWidth = 1
        keycap.layer?.borderColor = NSColor.separatorColor.cgColor
        keycap.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        keycap.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keycap.widthAnchor.constraint(equalToConstant: 120),
            keycap.heightAnchor.constraint(equalToConstant: 56),
        ])
        stack.addArrangedSubview(keycap)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let sample = NSButton(
            title: "Hear a Sample",
            target: self,
            action: #selector(hearSample)
        )
        sample.bezelStyle = .rounded
        buttons.addArrangedSubview(sample)

        let done = NSButton(
            title: "Done",
            target: self,
            action: #selector(done)
        )
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        buttons.addArrangedSubview(done)
        stack.addArrangedSubview(buttons)

        let checkbox = NSButton(
            checkboxWithTitle: "Open Speak11 when you log in",
            target: nil,
            action: nil
        )
        checkbox.state = .off
        launchAtLoginCheckbox = checkbox
        stack.addArrangedSubview(checkbox)
    }

    private var downloadTitle: String {
        switch flow {
        case .firstRun:
            "Downloading the voice"
        case .modelRecovery:
            "Restoring the voice"
        }
    }

    private var downloadBody: String {
        switch flow {
        case .firstRun:
            "A one-time download of about 200 MB. After this, everything stays on your Mac — selected text is never sent anywhere."
        case .modelRecovery:
            "The local voice files are missing. Speak11 will download them again now."
        }
    }

    private func titleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func bodyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .labelColor
        return label
    }

    private func secondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func tryDownloadAgain() {
        apply(.retryDownload)
    }

    @objc private func hearSample() {
        speechController.speak(
            "Speak11 is ready. Select text anywhere and press option A."
        )
    }

    @objc private func done() {
        if launchAtLoginCheckbox?.state == .on {
            enableLaunchAtLogin()
        }
        finish(.completedFirstRun)
    }

    private func enableLaunchAtLogin() {
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Launch at Login Could Not Be Changed"
            alert.runModal()
        }
    }

    private func finish(_ completion: Completion) {
        guard !didFinish else { return }
        didFinish = true
        cancel()
        window.close()
        NSApp.setActivationPolicy(.accessory)
        onCompletion(completion)
    }
}

private extension OnboardingDownloadPhase {
    init(_ phase: DownloadPhase) {
        switch phase {
        case .listing:
            self = .listing
        case let .downloading(
            completedFiles: completedFiles,
            totalFiles: totalFiles
        ):
            self = .downloading(
                completedFiles: completedFiles,
                totalFiles: totalFiles
            )
        case let .compiling(modelName: modelName):
            self = .compiling(modelName: modelName)
        @unknown default:
            self = .listing
        }
    }
}
