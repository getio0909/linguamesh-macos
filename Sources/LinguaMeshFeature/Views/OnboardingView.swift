import SwiftUI

@MainActor
public struct OnboardingView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(model.localized("onboarding.title", fallback: "Welcome to LinguaMesh"))
                .font(.largeTitle.bold())
            Text(
                model.localized(
                    "onboarding.description",
                    fallback: "Configure a provider and model, then translate with streamed output."
                )
            )
            Text("This prerelease begins with a credential-free loopback provider. Remote authenticated translation remains disabled until the core secret-host protocol is available.")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Continue", action: model.completeOnboarding)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 560)
        .interactiveDismissDisabled()
    }
}
