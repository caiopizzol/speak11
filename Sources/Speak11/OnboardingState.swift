import Foundation

enum OnboardingLaunchDecision: Equatable, Sendable {
    case firstRun
    case modelRecovery
    case normal

    static func decide(
        onboardingCompleted: Bool,
        modelsAvailable: Bool
    ) -> OnboardingLaunchDecision {
        guard onboardingCompleted else { return .firstRun }
        return modelsAvailable ? .normal : .modelRecovery
    }
}

enum OnboardingFlow: Equatable, Sendable {
    case firstRun
    case modelRecovery
}

struct OnboardingState: Equatable, Sendable {
    var step: OnboardingStep

    init(step: OnboardingStep = .accessibility) {
        self.step = step
    }

    static func initial(for flow: OnboardingFlow) -> OnboardingState {
        switch flow {
        case .firstRun:
            OnboardingState(step: .accessibility)
        case .modelRecovery:
            OnboardingState(step: .initialDownload)
        }
    }

    func applying(_ event: OnboardingEvent) -> OnboardingState {
        var next = self
        next.step = step.applying(event)
        return next
    }

    func transitioning(
        _ event: OnboardingEvent,
        flow: OnboardingFlow
    ) -> OnboardingTransition {
        let next = applying(event)
        let outcome: OnboardingTransitionOutcome = switch (flow, step.kind, event) {
        case (.modelRecovery, .downloading, .downloadSucceeded):
            .finishRecovery
        default:
            .none
        }
        return OnboardingTransition(state: next, outcome: outcome)
    }
}

struct OnboardingTransition: Equatable, Sendable {
    let state: OnboardingState
    let outcome: OnboardingTransitionOutcome
}

enum OnboardingTransitionOutcome: Equatable, Sendable {
    case none
    case finishRecovery
}

enum OnboardingStep: Equatable, Sendable {
    case accessibility
    case downloading(progressFraction: Double, phaseLabel: String)
    case downloadFailed(message: String)
    case ready

    static var initialDownload: OnboardingStep {
        downloading(progressFraction: 0, phaseLabel: OnboardingDownloadPhase.listing.label)
    }

    var kind: OnboardingStepKind {
        switch self {
        case .accessibility:
            .accessibility
        case .downloading:
            .downloading
        case .downloadFailed:
            .downloadFailed
        case .ready:
            .ready
        }
    }

    func applying(_ event: OnboardingEvent) -> OnboardingStep {
        switch (self, event) {
        case (.accessibility, .accessibilityGranted):
            .initialDownload
        case (.downloading, let .downloadProgress(fraction, phase)):
            .downloading(
                progressFraction: OnboardingProgress.clamped(fraction),
                phaseLabel: phase.label
            )
        case (.downloading, .downloadSucceeded):
            .ready
        case (.downloading, let .downloadFailed(message)):
            .downloadFailed(message: message)
        case (.downloadFailed, .retryDownload):
            .initialDownload
        default:
            self
        }
    }
}

enum OnboardingStepKind: Equatable, Sendable {
    case accessibility
    case downloading
    case downloadFailed
    case ready
}

enum OnboardingEvent: Equatable, Sendable {
    case accessibilityGranted
    case downloadProgress(fraction: Double, phase: OnboardingDownloadPhase)
    case downloadSucceeded
    case downloadFailed(message: String)
    case retryDownload
}

enum OnboardingDownloadPhase: Equatable, Sendable {
    case listing
    case downloading(completedFiles: Int, totalFiles: Int)
    case compiling(modelName: String)

    var label: String {
        switch self {
        case .listing:
            "Preparing download…"
        case let .downloading(completedFiles: completedFiles, totalFiles: totalFiles):
            "Downloading model files (\(completedFiles) of \(totalFiles))"
        case .compiling:
            "Preparing the voice…"
        }
    }
}

enum OnboardingProgress {
    static func clamped(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }
}
