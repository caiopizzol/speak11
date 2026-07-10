import Foundation

enum Preferences {
    private static let speakingRateKey = "speakingRate"
    private static let onboardingCompletedKey = "onboardingCompleted"

    static var speakingRate: Float {
        get {
            let stored = UserDefaults.standard.float(forKey: speakingRateKey)
            return stored == 0 ? 1 : min(max(stored, 0.75), 2)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.75), 2), forKey: speakingRateKey)
        }
    }

    static var onboardingCompleted: Bool {
        get {
            UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey)
        }
    }

    static var readsClipboardWhenNothingSelected: Bool {
        get {
            UserDefaults.standard.bool(forKey: readsClipboardKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: readsClipboardKey)
        }
    }

    private static let readsClipboardKey = "readsClipboardWhenNothingSelected"
}
