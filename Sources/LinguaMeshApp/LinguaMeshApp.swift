import LinguaMeshFeature
import SwiftUI

@main
@MainActor
struct LinguaMeshDesktopApp: App {
    @StateObject private var model = AppModel.live()

    var body: some Scene {
        WindowGroup("LinguaMesh") {
            RootView(model: model)
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandMenu("Translation") {
                Button(
                    model.localized("action.translate", fallback: "Translate"),
                    action: model.translate
                )
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.state.phase.isActive || model.state.sourceText.isEmpty)
                Button(
                    model.localized("action.cancel", fallback: "Cancel"),
                    action: model.cancel
                )
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.state.phase.isActive)
                Divider()
                Button("Clear", action: model.clear)
                    .disabled(model.state.phase.isActive)
            }
        }

        Settings {
            PreferencesView(model: model)
                .environment(\.locale, model.state.uiLocale.locale)
                .environment(
                    \.layoutDirection,
                    model.state.uiLocale.isRightToLeft ? .rightToLeft : .leftToRight
                )
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch model.state.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
