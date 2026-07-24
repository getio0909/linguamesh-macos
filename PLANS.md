# macOS Native Slice Plan

Status: Active

Authority: `GLOBAL_GOAL.md` and the sibling `linguamesh-project/PROJECT_GOAL.md`

## Goal

Deliver a real SwiftUI/AppKit text-translation slice that calls the generated LinguaMesh Core Swift wrapper, streams a loopback fake-provider response, cancels an active operation, stores credentials only in Keychain, switches theme and locale without losing text, and exposes redacted compatibility diagnostics.

## Assumptions

Assumption: The prerelease core Swift package in `../linguamesh-core/bindings/apple` is the only native boundary; the application may temporarily own a small, tested Protobuf wire codec inside `CoreBridge` because typed generated Swift protocol messages are not yet available.

Assumption: Provider profiles remain session-only until the core protocol exposes profile persistence. Only theme, locale, and onboarding completion may use `UserDefaults`; credential values use Keychain Services exclusively.

Assumption: Core ABI 1 emits one typed `secret_required` event for a session `SecretRef`; this client resolves the corresponding Keychain account and replies once through the raw Apple wrapper method while generated Swift protocol projections remain unavailable.

Assumption: Linux source checks are evidence only for repository hygiene. A macOS GitHub Actions runner must build the XCFramework, compile the package, run XCTest, exercise the real wrapper against the fake provider, and assemble an ad-hoc-signed smoke-test app before product-build claims are made.

## Steps

- [x] Verify the pinned global goal and inspect existing repository state.
- [x] Implement immutable application state, the isolated core bridge, Keychain services, native views, runtime locale/theme handling, and redacted diagnostics.
- [x] Add unit, Keychain, protocol, cancellation, and real-wrapper integration tests.
- [x] Add deterministic localization synchronization, macOS CI, and unsigned app-bundle packaging.
- [x] Run local hygiene checks and record unavailable local Xcode validation accurately.
- [ ] Obtain and record successful macOS CI evidence for the typed host-secret head before marking the native slice verified.
