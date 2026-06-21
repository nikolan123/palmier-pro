import Foundation

enum GeneralPreferences {
    private static let confirmBeforeClosingProjectKey = "confirmBeforeClosingProject"

    static var confirmBeforeClosingProject: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: confirmBeforeClosingProjectKey) == nil { return true }
            return defaults.bool(forKey: confirmBeforeClosingProjectKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: confirmBeforeClosingProjectKey)
        }
    }
}
