# Implementation Status

Status: Milestone 3 partial checkpoint; source and macOS CI verified, release pending

Global goal SHA-256: `11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198`

## Implemented in source

- Swift 6 package with a native SwiftUI application, onboarding, navigation, settings, menu commands, runtime theme and locale switching, RTL environment, and AppKit `NSTextView` source/output controls.
- Main-actor observable model with value-type state and unidirectional actions. Active source and streamed output survive locale/theme changes, and cancellation retains partial output.
- One isolated `CoreBridge` that imports the generated `LinguaMeshCore` ABI-major-1/protocol-1 wrapper. It leaves engine-scoped buffer copying/release to that wrapper, performs ABI/protocol startup checks, builds the versioned command envelope, polls away from the UI actor, bounds its client buffer, validates event size, protocol, operation/correlation identity, order, and terminal state, and maps typed failures including resource exhaustion.
- Manual provider endpoint and model configuration, including a deliberate quick switch between the two fake-provider models. Remote HTTP is rejected; HTTPS and loopback HTTP follow project transport policy.
- Application-specific Keychain Generic Password storage with `WhenUnlockedThisDeviceOnly` accessibility. Credential values never enter `UserDefaults`, application state, core commands, diagnostics, or logs. Normal preferences contain only theme, locale, and onboarding completion.
- Typed localized error presentation and native resources copied exactly from the current `linguamesh-l10n` generated macOS String Catalog. The synchronized catalog contains 43 keys across the official and pseudo locales; non-English review status remains governed by the localization repository.
- Redacted diagnostics containing application/core contract versions, non-secret identifiers, UI preferences, and normalized error kinds only.
- XCTest source for protocol framing/malformed input, immutable streaming state, locale/theme retention, cancellation, immediate reuse after consumer cancellation, quick model switching, preference isolation, Keychain lifecycle, and real generated-wrapper translation/cancellation against a loopback SSE fake provider.
- A macOS GitHub Actions gate pinned to the macOS 15/Xcode 16.4 toolchain that builds and tests the sibling core Swift wrapper, checks localization/source hygiene, compiles with strict concurrency and warnings as errors, runs tests, assembles an app bundle, and performs an ad-hoc-signing smoke check.
- App Sandbox, network-client, user-selected-file, and app-scoped-bookmark entitlement declarations plus an unsigned bundle assembly script.

## Explicitly not verified or not implemented

- No host-installed Swift compiler, Xcode, `xcodebuild`, Apple SDK, or macOS runtime exists on this Debian host. The real package, XCTest targets, XCFramework linkage, app launch, Keychain behavior under the signed app, App Sandbox, entitlements, and package script have not been built or run locally.
- macOS Native workflow run `29765371920` passed source validation, Core XCFramework build, generated Swift wrapper tests, strict-concurrency client build, all unit/integration tests (including immediate reuse after cancellation), app bundle assembly, and ad-hoc signing smoke verification on macOS 15/Xcode 16.4.
- The workflow pins reviewed core ABI 1 source revision `0db51464a9359400a2754ee86b51be2709e73709`; it never consumes moving `main`. The pinned Core also keeps text that fits one chunk intact, preventing duplicate provider requests for short whitespace-containing input.
- Core protocol version 1 has no typed `SecretRequired`/`ProvideSecret` host messages. Keychain persistence is real, but stored credentials are not read or delivered to the core; authenticated remote-provider translation is therefore not claimed. The production slice currently targets credential-free endpoints such as the loopback fake provider.
- Model discovery, connection testing, core-owned provider-profile persistence, per-provider last-model persistence, and provider-secret host resolution are not exposed by the current native protocol. Manual session-only endpoint/model selection is implemented; durable one-click provider switching is not complete.
- Startup negotiates ABI major and protocol version only. Core semantic version, provider catalog version, feature flags, and immutable artifact checksum negotiation remain unavailable.
- The checked-in Protobuf codec is a small temporary bridge implementation. It must be replaced by generated typed Swift protocol messages when the core SDK publishes them.
- Canonical action, field, status, onboarding, diagnostics, and typed-error messages use the generated catalog, but several provider/help labels and actionable recovery suggestions still fall back to English because corresponding canonical keys do not exist. Full-window localization is not claimed.
- No VoiceOver session, Accessibility Inspector run, XCUITest, keyboard traversal audit, reduced-motion validation, high-contrast validation, or native RTL visual inspection has been performed. Accessibility labels and keyboard commands in source are not manual evidence.
- No dedicated `swift-format` gate, automated dependency-license audit, full secret-scanning engine, or static analyzer beyond strict compiler checks and the portable source-hygiene script is configured yet.
- Security-scoped bookmark lifecycle, file panels, drag-and-drop, document translation, history, routing, glossaries, translation memory, incognito mode, notifications, and recent documents are not implemented.
- No universal application binary, distribution signing, notarization, stapling, DMG, SBOM, checksum-pinned client dependency, stable tag, or release artifact exists. The CI ad-hoc signature is only a packaging smoke test.
- Mandatory acceptance scenarios 2, 3, 5, 6, 8, 13, 16, and 19 are not marked passed for macOS from this source checkpoint. Relevant test source exists for parts of scenarios 2, 5, 6, 8, 13, and 16, but platform execution evidence is still required.

## Local validation evidence

Validated on Debian x86_64 on 2026-07-17:

- `sha256sum ../linguamesh-project/PROJECT_GOAL.md` matched the pinned global-goal digest.
- `bash -n tools/check-source.sh tools/package-app.sh tools/sync-localization.sh tools/sync-l10n.sh` passed.
- `bash tools/check-source.sh` passed, including raw-C isolation, immutable Action references, comment policy, credential-signature, trailing-whitespace, patch-whitespace, project/goal pins, and localization checks.
- `bash tools/sync-l10n.sh --check` pinned l10n revision `7e8c987737444d4e0f8f2642b108eee4c7801f58` and reported `Localization resources are synchronized.`
- The sibling and committed `Localizable.xcstrings` files both had SHA-256 `19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36` at this checkpoint.
- Python 3.13 parsed the fake-provider fixture, the 43-key String Catalog, both plist files, and both GitHub Actions workflows; the portable syntax check passed.
- GitHub API reads confirmed that the pinned checkout and Rust-toolchain Action commits and the pinned project, core, and localization repository commits are reachable. The core header and generated wrapper at `0db51464a9359400a2754ee86b51be2709e73709` declare ABI major 1, protocol 1, engine-bound buffer release, and resource-exhaustion result mapping. Core Native SDK run `29764592256` passed its Linux, Windows, Android, and Apple jobs. macOS Native run `29765371920` passed the client gate at `72af2d4a5189cca73e93a983bde4415a1566d446`.
- A read-only `swift:6.1.2-noble` container typechecked the platform-neutral state, codec, bridge, model, and XCTest source against API-equivalent stubs with Swift 6 mode, complete strict concurrency, and warnings as errors. This did not validate real AppKit, Combine, Security, String Catalog compilation, XCFramework linkage, or app packaging.
- A standalone Python 3.13 smoke test launched the loopback fixture on a random port, verified both model identifiers, posted a chat-completions request, and observed streamed content plus `data: [DONE]`.
- `git diff --check` passed.

Not run locally: `swift build`, `swift test`, `bash ../linguamesh-core/tools/build-apple-sdk.sh`, `bash tools/package-app.sh`, `codesign`, `xcodebuild`, app launch, XCTest, XCUITest, VoiceOver, Accessibility Inspector, Instruments, signing, or notarization. These require the macOS CI or a supported Apple host.
