# Testing and Validation

## Source checks

With Git, ripgrep, standard POSIX tools, and the canonical sibling repositories present, run:

```sh
bash -n tools/check-source.sh tools/package-app.sh tools/sync-localization.sh tools/sync-l10n.sh
bash tools/check-source.sh
```

The source check verifies required inputs, the compatibility-pinned project revision and exact goal digest, exact localization generation, immutable GitHub Action references, the raw-C isolation boundary, comment policy, common credential signatures, trailing whitespace, and patch whitespace.

## macOS product checks

On a supported macOS host with Xcode command-line tools and Rust 1.93.0:

```sh
cd ../linguamesh-core
bash tools/build-apple-sdk.sh
swift test --package-path bindings/apple
cd ../linguamesh-macos
swift build --configuration debug -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
swift test --configuration debug --parallel -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete
bash tools/package-app.sh
codesign --force --deep --sign - --options runtime \
  --entitlements Packaging/LinguaMesh.entitlements dist/LinguaMesh.app
codesign --verify --deep --strict dist/LinguaMesh.app
```

XCTest covers Protobuf framing and malformed data, immutable state updates, streamed output, cancellation with partial output, immediate reuse after consumer cancellation, UI locale/theme preservation, preference isolation, Keychain lifecycle, and the real generated core wrapper against a loopback OpenAI-compatible SSE fixture. The credentialed fixture path proves a one-shot Keychain secret response without a commercial credential; the fixture uses Python's standard library.

## Validation matrix

| Activity | Current command | Status |
| --- | --- | --- |
| Setup | `bash ../linguamesh-core/tools/build-apple-sdk.sh` | Requires macOS, Xcode, and pinned Rust |
| Localization | `bash tools/sync-l10n.sh --check` | Portable with pinned sibling l10n checkout |
| Lint | `bash tools/check-source.sh` | Portable source/security checks |
| Build | `swift build ...` | macOS CI gate |
| Test | `swift test ...` | macOS CI gate |
| Package | `bash tools/package-app.sh` | Unsigned app-bundle smoke test |

The ad-hoc signature validates bundle structure and entitlements only. XCUITest, VoiceOver inspection, security-scoped bookmark tests, distribution signing, notarization, and DMG validation remain future gates. Do not infer those results from unit tests.
