# Implementation Status

Status: Milestone 3 partial checkpoint; source and macOS CI verified, release pending

Global goal SHA-256: `11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198`

## 2026-07-27 Central project-spec pin refresh

Assumption: the macOS workflow must consume the current central prerelease coordination commit;
this CI pin refresh does not claim distribution signing, notarization, device, or stable evidence.

- The workflow project checkout and portable source gate now pin central
  `44068ddd750282e9ffa69c9816b4361ac1858641`, which records the published `.4` manifest and
  current cross-repository evidence.
- Core and localization pins remain `cb061d24a3e0c4059a65d099d30bc643e9e079ea` and
  `43f5a6f069f6d0e6d075517b0c017784fe505b0d`; the next Hosted macOS run must verify all three.

## 2026-07-27 Hosted prerelease artifact checkpoint

Assumption: the ad-hoc signed archive is packaging evidence only; distribution signing,
notarization, device, accessibility, rollback, and stable-release gates remain open.

- Commit `a8af9945c1c2b8080845e58e485c60df94ca1ccb` consumes Core
  `cb061d24a3e0c4059a65d099d30bc643e9e079ea` and l10n
  `43f5a6f069f6d0e6d075517b0c017784fe505b0d`.
- Hosted Native run `30287237127` passed source/localization validation, Core XCFramework build,
  generated wrapper tests, strict Swift build/tests, app assembly, ad-hoc signing, and artifact
  staging. Foundation `30287237210` passed.
- The uploaded `LinguaMesh-macos-prerelease-adhoc.zip` has SHA-256
  `9d5bfd4c27ade6bbfb27a28f7958e6cb2dd91522f28a4ecb25a694d0ee5d92ce`; a clean download passed
  `shasum -a 256` verification.
- The archive is not notarized or distribution-signed; no stable-release claim is made.

## 2026-07-27 Central Linux-first prerelease pin alignment

Assumption: the central prerelease compatibility train is the authoritative macOS CI input; the
pin update does not claim device, accessibility, notarization, or stable-release evidence.

- Workflow, source hygiene, and localization checks now consume Core
  `cb061d24a3e0c4059a65d099d30bc643e9e079ea` and l10n
  `43f5a6f069f6d0e6d075517b0c017784fe505b0d`, matching central `release-manifest.toml`.
- Hosted macOS validation for this exact pair is required before adding a macOS artifact to the
  central prerelease; device, accessibility, notarization, and distribution gates remain open.

## 2026-07-24 Core VFS-descendant macOS compatibility checkpoint

Assumption: Core `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` preserves the ABI-1 typed host-secret
contract while adding Linux-only storage coverage; macOS does not depend on Linux VFS behavior.

- macOS workflow and source gates now pin Core `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` and
  l10n `7fd210692bb269ef52f7453bfeb2b0f0759b1d4c`. The generated catalog bytes remain identical.
- Hosted macOS workflow `30101369965` rebuilt the exact Core XCFramework and passed generated
  wrapper tests, strict Swift concurrency, the full unit/integration suite, app assembly, and
  ad-hoc signing smoke. Release remains `unreleased` because distribution, device/accessibility,
  document, and rollback evidence is incomplete.
- Existing typed host-secret tests remain bounded and no-secret; app accessibility, profile
  persistence, document workflows, signing, rollback, and stable-release evidence remain open.

## 2026-07-24 typed host-secret checkpoint

- `CoreBridge` now sends `secret_ref` in the version-1 translation command, decodes the matching `secret_required` event, resolves the requested account through the injected Keychain `CredentialStore`, and sends a bounded one-shot `host_secret_response` with `provided`, `unavailable`, or `secure_storage_unavailable` resolution. Secret values remain out of logs, diagnostics, and persisted application state.
- The loopback fixture requires `Authorization: Bearer host-secret` for the credentialed path, and the real-wrapper XCTest covers Keychain-to-Core resolution and streamed completion. The generated Apple wrapper remains the only ABI boundary; the small codec is temporary until typed Swift protocol projections are published.
- Core source is pinned to `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` for this checkpoint. Release status remains unreleased.

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
- Typed version-1 host-secret transport is now implemented and covered by source tests plus hosted macOS run `30095987188` (Core XCFramework, strict Swift, 20 XCTest cases, app bundle, and ad-hoc signing smoke). Keychain account/profile persistence and provider model discovery remain outside this slice; authenticated remote-provider qualification beyond the loopback fixture remains open.
- Model discovery, connection testing, core-owned provider-profile persistence, per-provider last-model persistence, and provider-secret host resolution are not exposed by the current native protocol. Manual session-only endpoint/model selection is implemented; durable one-click provider switching is not complete.
- Startup negotiates ABI major and protocol version only. Core semantic version, provider catalog version, feature flags, and immutable artifact checksum negotiation remain unavailable.
- The checked-in Protobuf codec is a small temporary bridge implementation, including host-secret messages. It must be replaced by generated typed Swift protocol messages when the core SDK publishes them.
- Canonical action, field, status, onboarding, diagnostics, and typed-error messages use the generated catalog, but several provider/help labels and actionable recovery suggestions still fall back to English because corresponding canonical keys do not exist. Full-window localization is not claimed.
- No VoiceOver session, Accessibility Inspector run, XCUITest, keyboard traversal audit, reduced-motion validation, high-contrast validation, or native RTL visual inspection has been performed. Accessibility labels and keyboard commands in source are not manual evidence.
- No dedicated `swift-format` gate, automated dependency-license audit, full secret-scanning engine, or static analyzer beyond strict compiler checks and the portable source-hygiene script is configured yet.
- Security-scoped bookmark lifecycle, file panels, drag-and-drop, document translation, history, routing, glossaries, translation memory, incognito mode, notifications, and recent documents are not implemented.
- No universal application binary, distribution signing, notarization, stapling, DMG, SBOM, checksum-pinned client dependency, stable tag, or release artifact exists. The CI ad-hoc signature is only a packaging smoke test.
- Mandatory acceptance scenarios 2, 3, 5, 6, 8, 13, 16, and 19 are not marked passed for macOS from this source checkpoint. Relevant test source exists for parts of scenarios 2, 5, 6, 8, 13, and 16, but platform execution evidence is still required.

## Local validation evidence

Validated on Debian x86_64 on 2026-07-24:

- `sha256sum ../linguamesh-project/PROJECT_GOAL.md` matched the pinned global-goal digest.
- `bash -n tools/check-source.sh tools/package-app.sh tools/sync-localization.sh tools/sync-l10n.sh` passed.
- With the l10n sibling temporarily detached at the pinned `7e8c987737444d4e0f8f2642b108eee4c7801f58`, `bash tools/check-source.sh`, `bash tools/sync-l10n.sh --check`, `bash -n tools/check-source.sh tools/package-app.sh tools/sync-localization.sh tools/sync-l10n.sh`, and `git diff --check` passed. The sibling was restored cleanly to its `main` branch afterward.
- The sibling and committed `Localizable.xcstrings` files both had SHA-256 `19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36` at this checkpoint.
- Python 3.13 parsed the fake-provider fixture, the 43-key String Catalog, both plist files, and both GitHub Actions workflows; the portable syntax check passed.
- GitHub API reads confirmed that the pinned checkout and Rust-toolchain Action commits and the pinned project, core, and localization repository commits are reachable. The core header and generated wrapper at `0db51464a9359400a2754ee86b51be2709e73709` declare ABI major 1, protocol 1, engine-bound buffer release, and resource-exhaustion result mapping. Core Native SDK run `29764592256` passed its Linux, Windows, Android, and Apple jobs. macOS Native run `29765371920` passed the client gate at `72af2d4a5189cca73e93a983bde4415a1566d446`.
- A read-only `swift:6.1.2-noble` container typechecked the platform-neutral state, codec, bridge, model, and XCTest source against API-equivalent stubs with Swift 6 mode, complete strict concurrency, and warnings as errors. This did not validate real AppKit, Combine, Security, String Catalog compilation, XCFramework linkage, or app packaging.
- A standalone Python 3.13 smoke test launched the loopback fixture on a random port, verified both model identifiers, posted a chat-completions request, and observed streamed content plus `data: [DONE]`.
- `git diff --check` passed.

Not run locally: `swift build`, `swift test`, `bash ../linguamesh-core/tools/build-apple-sdk.sh`, `bash tools/package-app.sh`, `codesign`, `xcodebuild`, app launch, XCTest, XCUITest, VoiceOver, Accessibility Inspector, Instruments, signing, or notarization. These require the macOS CI or a supported Apple host. The hosted gate `30095987188` is authoritative for the new credentialed integration test and packaging smoke; manual accessibility and distribution signing remain unverified.
