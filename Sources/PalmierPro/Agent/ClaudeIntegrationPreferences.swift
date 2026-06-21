import Foundation

enum ClaudeIntegrationPreferences {
    private static let enabledKey = "io.palmier.pro.claude.enabled"

    static var isEnabled: Bool {
        get { isEnabled(in: .standard) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? false
    }
}
