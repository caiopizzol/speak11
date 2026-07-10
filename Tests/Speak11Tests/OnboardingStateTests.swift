import Testing
@testable import Speak11

struct OnboardingStateTests {
    @Test
    func launchDecisionMatrix() {
        #expect(OnboardingLaunchDecision.decide(
            onboardingCompleted: false,
            modelsAvailable: false
        ) == .firstRun)
        #expect(OnboardingLaunchDecision.decide(
            onboardingCompleted: false,
            modelsAvailable: true
        ) == .firstRun)
        #expect(OnboardingLaunchDecision.decide(
            onboardingCompleted: true,
            modelsAvailable: false
        ) == .modelRecovery)
        #expect(OnboardingLaunchDecision.decide(
            onboardingCompleted: true,
            modelsAvailable: true
        ) == .normal)
    }

    @Test
    func accessibilityGrantStartsDownload() {
        let state = OnboardingState()
            .applying(.accessibilityGranted)

        #expect(state.step == .initialDownload)
    }

    @Test
    func modelRecoveryStartsAtDownload() {
        let state = OnboardingState.initial(for: .modelRecovery)

        #expect(state.step == .initialDownload)
    }

    @Test
    func downloadSuccessReachesReady() {
        let state = OnboardingState(step: .initialDownload)
            .applying(.downloadSucceeded)

        #expect(state.step == .ready)
    }

    @Test
    func modelRecoveryDownloadSuccessFinishesRecovery() {
        let transition = OnboardingState(step: .initialDownload)
            .transitioning(.downloadSucceeded, flow: .modelRecovery)

        #expect(transition == OnboardingTransition(
            state: OnboardingState(step: .ready),
            outcome: .finishRecovery
        ))
    }

    @Test
    func downloadFailureShowsFailureMessage() {
        let state = OnboardingState(step: .initialDownload)
            .applying(.downloadFailed(message: "Network unavailable."))

        #expect(state.step == .downloadFailed(message: "Network unavailable."))
    }

    @Test
    func retryRestartsDownload() {
        let state = OnboardingState(step: .downloadFailed(message: "No connection."))
            .applying(.retryDownload)

        #expect(state.step == .initialDownload)
    }

    @Test
    func phaseLabelsMatchOnboardingCopy() {
        #expect(OnboardingDownloadPhase.listing.label == "Preparing download…")
        #expect(OnboardingDownloadPhase.downloading(
            completedFiles: 2,
            totalFiles: 5
        ).label == "Downloading model files (2 of 5)")
        #expect(OnboardingDownloadPhase.compiling(
            modelName: "kokoro"
        ).label == "Preparing the voice…")
    }

    @Test
    func progressFractionIsClamped() {
        #expect(OnboardingProgress.clamped(-0.25) == 0)
        #expect(OnboardingProgress.clamped(0.5) == 0.5)
        #expect(OnboardingProgress.clamped(1.25) == 1)

        let state = OnboardingState(step: .initialDownload)
            .applying(.downloadProgress(
                fraction: 1.25,
                phase: .listing
            ))

        #expect(state.step == .downloading(
            progressFraction: 1,
            phaseLabel: "Preparing download…"
        ))
    }
}
