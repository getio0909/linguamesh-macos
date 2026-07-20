# macOS Architecture

## Implemented slice

`LinguaMeshApp` is a small SwiftUI application target. `LinguaMeshFeature` owns immutable value state, a main-actor observable model, SwiftUI views, an AppKit `NSTextView` bridge, Keychain access, localization lookup, and the native core boundary. Provider transport, streaming parsing, cancellation semantics, and typed provider errors remain in `linguamesh-core`.

The state flow is unidirectional:

1. a native view sends a deliberate action to `AppModel`;
2. the model snapshots a non-secret request and submits it through `CoreClient`;
3. `NativeCoreClient` uses only the generated `LinguaMeshCore` Swift wrapper;
4. a detached non-UI task performs bounded event polling and validates protocol version, operation and correlation identity, sequence order, message size, and event type;
5. consumer cancellation requests core cancellation, drains for at most two seconds to the matching terminal event, and recreates the session before another request can be accepted;
6. the main actor replaces or appends immutable state values for SwiftUI rendering.

The temporary Protobuf encoder/decoder is contained in `CoreBridge/ProtocolCodec.swift`. It exists because the prerelease core package does not yet ship typed generated Swift protocol messages. The generated wrapper keeps its engine handle alive while it copies and releases each engine-owned event buffer; application code never handles that pointer or calls raw C symbols.

## Native ownership

SwiftUI provides onboarding, navigation, forms, settings, alerts, theme, locale environment, RTL direction, and menu commands. AppKit provides scalable editable/selectable text views and clipboard integration. `UserDefaultsUIPreferences` stores only theme, locale, and onboarding completion. Provider name, endpoint, and model remain session-only until core-owned profile APIs exist.

## Security boundaries

`KeychainCredentialStore` uses an application-specific Generic Password service and device-local accessibility. The UI clears its transient `SecureField` value immediately after requesting a save. Diagnostics contain only versions, configuration identifiers, and normalized error categories; they exclude credential values, authorization data, source text, output, and endpoint query data.

Core protocol version 1 cannot request a `SecretRef`, so the stored credential is not read or sent during translation. The current product path is intentionally limited to credential-free endpoints such as the loopback fake provider. Typed one-time host secret responses must be added to the core contract before remote authenticated translation can be claimed.

Persistent document access is not implemented. Future file work must use balanced security-scoped URLs and bookmarks. Signing and notarization material remains outside source and untrusted CI.

Architectural changes affecting the ABI, protocol, sandbox, persistence ownership, or distribution model require a central compatibility decision before implementation.
