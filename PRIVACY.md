# Privacy

LinguaMesh for macOS has no default telemetry and no LinguaMesh account. Translation text is submitted only after the UI identifies the active provider and the user invokes Translate. The current prerelease slice supports credential-free endpoints and is intended for the loopback fake provider; authenticated remote-provider delivery is not implemented.

Provider credentials are written to an application-specific Keychain service. Credential values are not placed in `UserDefaults`, application state, core commands, diagnostics, or logs. Theme, interface locale, and onboarding completion are the only currently persisted normal preferences. Provider name, endpoint, model, source text, and translated output remain in memory for the application session.

Diagnostics expose application version, core ABI and protocol versions, provider/model identifiers, UI preferences, and normalized error categories. They exclude credentials, authorization headers, source text, translated output, and query-bearing endpoint data. The application does not log translation content.

The configured provider's own privacy terms govern any content deliberately sent to it. Use loopback endpoints for local-only processing. Report privacy or credential-handling defects through the private route in `SECURITY.md`.
