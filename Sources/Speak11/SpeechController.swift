import AVFoundation
import FluidAudio
import Foundation

enum SpeechFailure: Equatable {
    case modelPreparation(message: String)
    case synthesis(text: String, message: String)
    case playback(text: String, message: String)

    var retryTarget: SpeechRetryTarget {
        switch self {
        case .modelPreparation:
            .prepareVoice
        case let .synthesis(text, _), let .playback(text, _):
            .speak(text)
        }
    }

    var menuSummary: String {
        let summary = switch self {
        case let .modelPreparation(message):
            "Voice preparation failed: \(message)"
        case let .synthesis(_, message):
            "Speech synthesis failed: \(message)"
        case let .playback(_, message):
            "Playback failed: \(message)"
        }
        return Self.truncated(Self.oneLine(summary))
    }

    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func truncated(_ text: String) -> String {
        let maximumLength = 96
        guard text.count > maximumLength else { return text }
        return "\(text.prefix(maximumLength - 1))…"
    }
}

enum SpeechRetryTarget: Equatable {
    case prepareVoice
    case speak(String)
}

enum SpeechSpeed {
    static func isLookaheadStale(synthesizedSpeed: Float, currentSpeed: Float) -> Bool {
        abs(synthesizedSpeed - currentSpeed) >= 0.001
    }
}

@MainActor
final class SpeechController {
    enum State: Equatable {
        case idle
        case preparing
        case speaking
        case failed(SpeechFailure)
    }

    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }
    private(set) var isVoicePrepared = false

    var isActive: Bool {
        state == .preparing || state == .speaking
    }

    private let engine = KokoroAneManager()
    private var audioPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?
    private var inFlightSynthesis: Task<Data, Error>?
    private var inFlightSynthesisID: UUID?
    private var generation = 0

    func prepareVoice() {
        guard !isActive, !isVoicePrepared else { return }
        begin { [weak self] generation in
            guard let self else { return }
            try await prepareForSpeech()
            guard isCurrent(generation) else { return }
            state = .idle
        }
    }

    func speak(_ text: String) {
        guard let requestText = TextNormalizer.normalize(text) else { return }
        let chunks = TextChunker.chunks(from: requestText)
        guard !chunks.isEmpty else { return }

        begin { [weak self] generation in
            guard let self else { return }
            try await prepareForSpeech()
            try await play(
                requestText: requestText,
                chunks: chunks,
                generation: generation
            )
            guard isCurrent(generation) else { return }
            state = .idle
        }
    }

    func retry() {
        guard case let .failed(failure) = state else { return }
        switch failure.retryTarget {
        case .prepareVoice:
            prepareVoice()
        case let .speak(text):
            speak(text)
        }
    }

    func stop() {
        generation += 1
        speechTask?.cancel()
        speechTask = nil
        inFlightSynthesis?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle
    }

    private func begin(
        operation: @escaping @MainActor (Int) async throws -> Void
    ) {
        stop()
        generation += 1
        let currentGeneration = generation
        state = .preparing

        speechTask = Task { [weak self] in
            do {
                try await operation(currentGeneration)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(currentGeneration) else { return }
                self.audioPlayer = nil
                if let speechError = error as? SpeechOperationFailure {
                    self.state = .failed(speechError.failure)
                } else {
                    self.state = .failed(.modelPreparation(
                        message: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func prepareForSpeech() async throws {
        do {
            try await prepareEngine()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SpeechOperationFailure(.modelPreparation(
                message: error.localizedDescription
            ))
        }
    }

    private func prepareEngine() async throws {
        guard !isVoicePrepared else { return }
        try await engine.initialize()
        try Task.checkCancellation()
        isVoicePrepared = true
    }

    private func play(
        requestText: String,
        chunks: [String],
        generation: Int
    ) async throws {
        var pendingAudio = queuedAudio(
            for: chunks[0],
            requestText: requestText,
            speed: Preferences.speakingRate,
            generation: generation
        )
        defer { pendingAudio.cancel() }

        for index in chunks.indices {
            let speed = Preferences.speakingRate
            if SpeechSpeed.isLookaheadStale(
                synthesizedSpeed: pendingAudio.speed,
                currentSpeed: speed
            ) {
                pendingAudio.cancel()
                pendingAudio = queuedAudio(
                    for: chunks[index],
                    requestText: requestText,
                    speed: speed,
                    generation: generation
                )
            }

            let audio = try await pendingAudio.task.value
            try Task.checkCancellation()
            guard isCurrent(generation) else { throw CancellationError() }

            if chunks.indices.contains(index + 1) {
                let nextText = chunks[index + 1]
                pendingAudio = queuedAudio(
                    for: nextText,
                    requestText: requestText,
                    speed: speed,
                    generation: generation
                )
            }

            state = .speaking
            do {
                try await playAudio(audio, generation: generation)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw SpeechOperationFailure(.playback(
                    text: requestText,
                    message: error.localizedDescription
                ))
            }
        }
    }

    private func queuedAudio(
        for chunk: String,
        requestText: String,
        speed: Float,
        generation: Int
    ) -> QueuedAudio {
        QueuedAudio(
            speed: speed,
            task: Task { [weak self] in
                guard let self else { throw CancellationError() }
                do {
                    return try await synthesize(
                        chunk,
                        speed: speed,
                        generation: generation
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    throw SpeechOperationFailure(.synthesis(
                        text: requestText,
                        message: error.localizedDescription
                    ))
                }
            }
        )
    }

    private func playAudio(_ data: Data, generation: Int) async throws {
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        guard player.play() else {
            throw SpeechError.playbackFailed
        }
        audioPlayer = player

        while player.isPlaying {
            try await Task.sleep(for: .milliseconds(50))
            guard isCurrent(generation) else { throw CancellationError() }
        }
        audioPlayer = nil
    }

    private func synthesize(
        _ text: String,
        speed: Float,
        generation: Int
    ) async throws -> Data {
        if let existing = inFlightSynthesis {
            _ = try? await existing.value
        }
        try Task.checkCancellation()
        guard isCurrent(generation) else { throw CancellationError() }

        let synthesisID = UUID()
        let task = Task {
            try Task.checkCancellation()
            return try await engine.synthesize(text: text, speed: speed)
        }
        inFlightSynthesis = task
        inFlightSynthesisID = synthesisID

        defer {
            if inFlightSynthesisID == synthesisID {
                inFlightSynthesis = nil
                inFlightSynthesisID = nil
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func isCurrent(_ value: Int) -> Bool {
        value == generation && !Task.isCancelled
    }
}

private struct QueuedAudio {
    let speed: Float
    let task: Task<Data, Error>

    func cancel() {
        task.cancel()
    }
}

private struct SpeechOperationFailure: Error {
    let failure: SpeechFailure

    init(_ failure: SpeechFailure) {
        self.failure = failure
    }
}

private enum SpeechError: LocalizedError {
    case playbackFailed

    var errorDescription: String? {
        "The generated audio could not be played."
    }
}
