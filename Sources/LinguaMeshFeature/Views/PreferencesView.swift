import SwiftUI

@MainActor
public struct PreferencesView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Picker(
                model.localized("settings.theme", fallback: "Theme"),
                selection: Binding(
                    get: { model.state.theme },
                    set: model.setTheme
                )
            ) {
                Text(model.localized("theme.system", fallback: "System")).tag(ThemePreference.system)
                Text(model.localized("theme.light", fallback: "Light")).tag(ThemePreference.light)
                Text(model.localized("theme.dark", fallback: "Dark")).tag(ThemePreference.dark)
            }
            Picker(
                model.localized("settings.ui_language", fallback: "Interface language"),
                selection: Binding(
                    get: { model.state.uiLocale },
                    set: model.setLocale
                )
            ) {
                ForEach(UILocale.allCases) { locale in
                    Text(locale.displayName).tag(locale)
                }
            }
            Text(
                model.localized(
                    "locale.current",
                    fallback: "Interface language: %1$@",
                    arguments: [model.state.uiLocale.displayName]
                )
            )
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 480)
    }
}
