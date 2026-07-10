import Testing
@testable import Speak11

struct SpeechControllerTests {
    @Test
    func modelPreparationFailureRetriesPreparation() {
        let failure = SpeechFailure.modelPreparation(message: "download failed")

        #expect(failure.retryTarget == .prepareVoice)
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
    func failureSummaryIsOneLine() {
        let failure = SpeechFailure.playback(
            text: "Text",
            message: "first line\nsecond line"
        )

        #expect(failure.menuSummary == "Playback failed: first line second line")
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
