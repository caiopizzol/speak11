import AVFoundation
import FluidAudio
import Foundation

@MainActor
final class SpeechController {
    enum State: Equatable {
        case idle
        case preparing
        case speaking
        case failed(String)
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
            try await prepareEngine()
            guard isCurrent(generation) else { return }
            state = .idle
        }
    }

    func speak(_ text: String) {
        let chunks = TextChunker.chunks(from: text)
        guard !chunks.isEmpty else { return }

        begin { [weak self] generation in
            guard let self else { return }
            try await prepareEngine()
            try await play(chunks: chunks, generation: generation)
            guard isCurrent(generation) else { return }
            state = .idle
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
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    private func prepareEngine() async throws {
        guard !isVoicePrepared else { return }
        try await engine.initialize()
        try Task.checkCancellation()
        isVoicePrepared = true
    }

    private func play(chunks: [String], generation: Int) async throws {
        let speed = Preferences.speakingRate
        var pendingAudio = Task {
            try await synthesize(chunks[0], speed: speed, generation: generation)
        }
        defer { pendingAudio.cancel() }

        for index in chunks.indices {
            let audio = try await pendingAudio.value
            try Task.checkCancellation()
            guard isCurrent(generation) else { throw CancellationError() }

            if chunks.indices.contains(index + 1) {
                let nextText = chunks[index + 1]
                pendingAudio = Task {
                    try await synthesize(nextText, speed: speed, generation: generation)
                }
            }

            state = .speaking
            try await playAudio(audio, generation: generation)
        }
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
            try await engine.synthesize(text: text, speed: speed)
        }
        inFlightSynthesis = task
        inFlightSynthesisID = synthesisID

        defer {
            if inFlightSynthesisID == synthesisID {
                inFlightSynthesis = nil
                inFlightSynthesisID = nil
            }
        }
        return try await task.value
    }

    private func isCurrent(_ value: Int) -> Bool {
        value == generation && !Task.isCancelled
    }
}

private enum SpeechError: LocalizedError {
    case playbackFailed

    var errorDescription: String? {
        "The generated audio could not be played."
    }
}
