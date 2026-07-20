import AppKit
import SwiftUI

@MainActor
public struct TextWorkspaceView: View {
    @ObservedObject private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                model.localized(
                    "provider.active",
                    fallback: "Active provider: %1$@",
                    arguments: [model.state.provider.displayName]
                )
            )
            .font(.headline)

            HStack {
                Text(
                    "\(model.localized("field.model", fallback: "Model")): \(model.state.provider.modelIdentifier)"
                )
                Spacer()
                Text(
                    model.localized(
                        "settings.target_language",
                        fallback: "Target language"
                    )
                )
                TextField(
                    "BCP 47 tag",
                    text: Binding(
                        get: { model.state.targetLocale },
                        set: model.setTargetLocale
                    )
                )
                .frame(width: 120)
            }

            HSplitView {
                GroupBox(model.localized("field.source_text", fallback: "Source text")) {
                    NativeTextEditor(
                        text: Binding(
                            get: { model.state.sourceText },
                            set: model.setSourceText
                        ),
                        isEditable: !model.state.phase.isActive,
                        accessibilityLabel: model.localized(
                            "accessibility.source_content",
                            fallback: "Source text to translate"
                        )
                    )
                }
                GroupBox(model.localized("field.translation", fallback: "Translation")) {
                    NativeTextEditor(
                        text: .constant(model.state.translatedText),
                        isEditable: false,
                        accessibilityLabel: model.localized(
                            "accessibility.translation_output",
                            fallback: "Streamed translation output"
                        )
                    )
                }
            }
            .frame(minHeight: 360)

            HStack(spacing: 10) {
                Button(
                    model.localized("action.translate", fallback: "Translate"),
                    action: model.translate
                )
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(
                    model.state.phase.isActive
                        || model.state.sourceText.isEmpty
                        || model.state.provider.modelIdentifier.isEmpty
                )

                Button(
                    model.localized("action.cancel", fallback: "Cancel"),
                    action: model.cancel
                )
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.state.phase.isActive)
                .accessibilityLabel(
                    model.localized(
                        "accessibility.stop_translation",
                        fallback: "Stop translation"
                    )
                )

                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(model.state.translatedText, forType: .string)
                }
                .disabled(model.state.translatedText.isEmpty)

                Button("Clear", action: model.clear)
                    .disabled(model.state.phase.isActive)

                Spacer()
                status
            }
        }
        .padding(20)
        .navigationTitle(
            model.localized("nav.text_translation", fallback: "Text translation")
        )
    }

    @ViewBuilder
    private var status: some View {
        if model.state.outputIsPartial {
            Label("Partial output retained", systemImage: "exclamationmark.circle")
                .foregroundStyle(.secondary)
        } else {
            Text(phaseLabel)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Translation status: \(phaseLabel)")
        }
    }

    private var phaseLabel: String {
        switch model.state.phase {
        case .idle, .completed:
            model.localized("status.ready", fallback: "Ready")
        case .starting, .streaming, .cancelling:
            model.localized("status.translating", fallback: "Translating…")
        case .cancelled:
            model.localized(
                "status.cancelled",
                fallback: "Translation cancelled. Partial output was kept."
            )
        case .failed:
            model.localized(
                "error.unknown",
                fallback: "Translation failed. Review diagnostics and try again."
            )
        }
    }
}
