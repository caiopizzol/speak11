import Foundation

enum Preferences {
    private static let speakingRateKey = "speakingRate"

    static var speakingRate: Float {
        get {
            let stored = UserDefaults.standard.float(forKey: speakingRateKey)
            return stored == 0 ? 1 : min(max(stored, 0.75), 2)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.75), 2), forKey: speakingRateKey)
        }
    }
}
