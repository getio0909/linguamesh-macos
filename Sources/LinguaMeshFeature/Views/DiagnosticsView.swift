import SwiftUI

@MainActor
public struct DiagnosticsView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Compatibility") {
                LabeledContent("Application version", value: model.state.diagnostics.appVersion)
                LabeledContent(
                    "Core ABI major",
                    value: String(model.state.diagnostics.coreCompatibility.abiMajor)
                )
                LabeledContent(
                    "Protocol version",
                    value: String(model.state.diagnostics.coreCompatibility.protocolVersion)
                )
            }
            Section("Current configuration") {
                LabeledContent("Provider", value: model.state.provider.displayName)
                LabeledContent("Model", value: model.state.provider.modelIdentifier)
                LabeledContent("Profile persistence", value: model.state.diagnostics.profilePersistence)
                LabeledContent("Credential transport", value: model.state.diagnostics.credentialTransport)
                LabeledContent("UI locale", value: model.state.uiLocale.rawValue)
                LabeledContent("Theme", value: model.state.theme.rawValue)
            }
            Section("Last safe error") {
                Text(model.state.diagnostics.lastSafeErrorKind?.rawValue ?? "None")
            }
            Section("Privacy") {
                Text("Diagnostics contain version identifiers and normalized categories only. Credentials, authorization headers, source text, translated output, and endpoint query data are excluded.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .navigationTitle(model.localized("diagnostics.title", fallback: "Diagnostics"))
    }
}
