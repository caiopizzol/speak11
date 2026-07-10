import Testing
@testable import Speak11

struct SpeechControllerTests {
    @Test
    func modelPreparationFailureDuringSpeechRetriesOriginalText() {
        let text = "The exact normalized request text."
        let failure = SpeechFailure.modelPreparation(
            text: text,
            message: "download failed"
        )

        #expect(failure.retryTarget == .speak(text))
    }

    @Test
    func modelPreparationFailureWithoutRequestRetriesPreparation() {
        let failure = SpeechFailure.modelPreparation(
            text: nil,
            message: "download failed"
        )

        #expect(failure.retryTarget == .prepareVoice)
    }

    @Test
    @MainActor
    func backgroundWarmupIsNotUserInitiatedActivity() {
        let controller = SpeechController()

        controller.warmUpVoice()
        #expect(controller.isActive)
        #expect(controller.isBackgroundWarmup)
        #expect(!controller.isUserInitiatedActive)

        controller.stop()
        #expect(!controller.isBackgroundWarmup)
        #expect(!controller.isActive)
    }

    @Test
    func synthesisFailureRetriesOriginalText() {
        let text = "The exact normalized request text."
        let failure = SpeechFailure.synthesis(text: text, message: "synthesis failed")

        #expect(failure.retryTarget == .speak(text))
    }

    @Test
    func playbackFailureRetriesOriginalText() {
        let text = "The exact normalized request text."
        let failure = SpeechFailure.playback(text: text, message: "playback failed")

        #expect(failure.retryTarget == .speak(text))
    }

    @Test
    func preparationSummaryOmitsRequestText() {
        let failure = SpeechFailure.modelPreparation(
            text: "Sensitive selection",
            message: "download failed"
        )

        #expect(failure.menuSummary == "Voice preparation failed: download failed")
    }

    @Test
    func failureSummaryIsOneLine() {
        let failure = SpeechFailure.playback(
            text: "Text",
            message: "first line\nsecond line"
        )

        #expect(failure.menuSummary == "Playback failed: first line second line")
    }

    @Test
    func playbackRateStretchesCurrentChunkTowardDesiredSpeed() {
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 2, synthesizedSpeed: 1) == 2)
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 1, synthesizedSpeed: 2) == 0.5)
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 1.5, synthesizedSpeed: 1.5) == 1)
    }

    @Test
    func playbackRateIsClampedToPlayerLimits() {
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 2, synthesizedSpeed: 0.75) == 2)
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 0.75, synthesizedSpeed: 2) == 0.5)
        #expect(SpeechSpeed.playbackRate(desiredSpeed: 1, synthesizedSpeed: 0) == 1)
    }

    @Test
    func lookaheadIsStaleOnlyWhenSpeedMeaningfullyChanges() {
        #expect(!SpeechSpeed.isLookaheadStale(
            synthesizedSpeed: 1,
            currentSpeed: 1.0005
        ))
        #expect(SpeechSpeed.isLookaheadStale(
            synthesizedSpeed: 1,
            currentSpeed: 1.25
        ))
        #expect(SpeechSpeed.isLookaheadStale(
            synthesizedSpeed: 1.5,
            currentSpeed: 1
        ))
    }
}
