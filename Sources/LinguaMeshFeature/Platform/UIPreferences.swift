import Foundation

@MainActor
public protocol UIPreferencesStore: AnyObject {
    func loadTheme() -> ThemePreference
    func loadLocale() -> UILocale
    func hasCompletedOnboarding() -> Bool
    func saveTheme(_ theme: ThemePreference)
    func saveLocale(_ locale: UILocale)
    func saveOnboardingCompleted()
}

@MainActor
public final class UserDefaultsUIPreferences: UIPreferencesStore {
    private enum Key {
        static let theme = "ui.theme"
        static let locale = "ui.locale"
        static let onboardingCompleted = "ui.onboarding-completed"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadTheme() -> ThemePreference {
        defaults.string(forKey: Key.theme).flatMap(ThemePreference.init(rawValue:)) ?? .system
    }

    public func loadLocale() -> UILocale {
        defaults.string(forKey: Key.locale).flatMap(UILocale.init(rawValue:)) ?? .english
    }

    public func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: Key.onboardingCompleted)
    }

    public func saveTheme(_ theme: ThemePreference) {
        defaults.set(theme.rawValue, forKey: Key.theme)
    }

    public func saveLocale(_ locale: UILocale) {
        defaults.set(locale.rawValue, forKey: Key.locale)
    }

    public func saveOnboardingCompleted() {
        defaults.set(true, forKey: Key.onboardingCompleted)
    }
}
