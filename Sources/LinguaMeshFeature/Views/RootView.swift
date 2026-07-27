import SwiftUI

private enum SidebarDestination: String, CaseIterable, Hashable, Identifiable {
    case translation
    case providers
    case diagnostics

    var id: String { rawValue }
}

@MainActor
public struct RootView: View {
    @ObservedObject private var model: AppModel
    @State private var selection: SidebarDestination? = .translation

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(
                    model.localized("nav.text_translation", fallback: "Text translation"),
                    systemImage: "character.cursor.ibeam"
                )
                .tag(SidebarDestination.translation)
                Label("Providers and Models", systemImage: "network")
                    .tag(SidebarDestination.providers)
                Label(
                    model.localized("diagnostics.title", fallback: "Diagnostics"),
                    systemImage: "stethoscope"
                )
                    .tag(SidebarDestination.diagnostics)
            }
            .navigationTitle(model.localized("app.title", fallback: "LinguaMesh"))
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            switch selection ?? .translation {
            case .translation:
                TextWorkspaceView(model: model)
            case .providers:
                ProviderSettingsView(model: model)
            case .diagnostics:
                DiagnosticsView(model: model)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .environment(\.locale, model.state.uiLocale.locale)
        .environment(
            \.layoutDirection,
            model.state.uiLocale.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .preferredColorScheme(preferredColorScheme)
        .task {
            await model.prepare()
        }
        .sheet(
            isPresented: Binding(
                get: { model.state.showsOnboarding },
                set: { isPresented in
                    if !isPresented {
                        model.completeOnboarding()
                    }
                }
            )
        ) {
            OnboardingView(model: model)
                .environment(\.locale, model.state.uiLocale.locale)
                .environment(
                    \.layoutDirection,
                    model.state.uiLocale.isRightToLeft ? .rightToLeft : .leftToRight
                )
        }
        .alert(
            model.state.presentedError?.message ?? "LinguaMesh",
            isPresented: Binding(
                get: { model.state.presentedError != nil },
                set: { isPresented in
                    if !isPresented {
                        model.dismissError()
                    }
                }
            )
        ) {
            Button("OK", action: model.dismissError)
        } message: {
            Text(model.state.presentedError?.recoverySuggestion ?? "")
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
