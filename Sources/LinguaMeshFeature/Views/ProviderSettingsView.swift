import SwiftUI

@MainActor
public struct ProviderSettingsView: View {
    @ObservedObject private var model: AppModel
    @State private var credential = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section("Provider profile") {
                TextField(
                    "Name",
                    text: Binding(
                        get: { model.state.provider.displayName },
                        set: model.setProviderName
                    )
                )
                TextField(
                    "Endpoint",
                    text: Binding(
                        get: { model.state.provider.endpoint },
                        set: model.setProviderEndpoint
                    )
                )
                Text("Remote endpoints require HTTPS. Loopback HTTP is allowed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                Picker(
                    "Quick switch",
                    selection: Binding(
                        get: { model.state.provider.modelIdentifier },
                        set: model.selectModel
                    )
                ) {
                    Text("fake-translator").tag("fake-translator")
                    Text("fake-slow-translator").tag("fake-slow-translator")
                }
                TextField(
                    "Manual model identifier",
                    text: Binding(
                        get: { model.state.provider.modelIdentifier },
                        set: model.selectModel
                    )
                )
                Text("Protocol version 1 supports manual model selection; discovery is not exposed by the native boundary yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Credential") {
                SecureField("API key", text: $credential)
                HStack {
                    Button("Save in Keychain") {
                        let value = credential
                        credential = ""
                        Task {
                            await model.saveCredential(value)
                        }
                    }
                    .disabled(credential.isEmpty)

                    Button("Delete", role: .destructive) {
                        credential = ""
                        Task {
                            await model.deleteCredential()
                        }
                    }
                    .disabled(!model.state.provider.hasStoredCredential)

                    Spacer()
                    Label(
                        model.state.provider.hasStoredCredential
                            ? "Stored in Keychain"
                            : "No stored credential",
                        systemImage: model.state.provider.hasStoredCredential
                            ? "checkmark.shield"
                            : "shield"
                    )
                }
                Text("The current core protocol cannot request credentials from the host. Stored values are never copied into preferences or diagnostics, and this prerelease translation slice is limited to credential-free endpoints.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Persistence") {
                Text("Provider and model changes are session-only until core-owned profile persistence is available.")
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(model.state.phase.isActive)
        .formStyle(.grouped)
        .padding(12)
        .navigationTitle("Providers and Models")
    }
}
