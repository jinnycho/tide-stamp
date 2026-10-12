import Foundation

enum AppPreferences {
    // A fixed domain keeps the documented defaults commands working for both
    // installed apps and builds launched with `swift run`.
    static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: "TideStamp") else {
            preconditionFailure("Could not open TideStamp preferences")
        }
        return defaults
    }()
}
