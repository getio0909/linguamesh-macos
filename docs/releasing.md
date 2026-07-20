# Releasing

## Current state

`tools/package-app.sh` assembles an unsigned prerelease app bundle from the Swift Package release executable and generated localization bundle. macOS Native CI run `29765371920` applies an ad-hoc signature solely to verify bundle structure, hardened-runtime options, and entitlements. No distribution-signed, notarized, stapled, DMG, or stable artifact exists.

Before packaging, build the core XCFramework from source revision `0db51464a9359400a2754ee86b51be2709e73709` and run all commands in `docs/testing.md`. CI pins that immutable source revision and run `29765371920` verified the client package against it. A release must use a verified immutable artifact and checksum from the central release manifest.

## Future release gate

A macOS release may be prepared only after:

1. the application and tests pass with documented Xcode and Swift versions;
2. the embedded LinguaMesh Core XCFramework, ABI, protocol, catalog, and localization versions match the central release manifest;
3. entitlements, App Sandbox permissions, Keychain access, security-scoped resources, accessibility, migrations, and packaging smoke tests are verified;
4. third-party notices, license review, privacy/security review, changelog, checksum, and rollback information are complete;
5. signing and notarization run only in protected release infrastructure and produce verifiable evidence.

The intended deliverables are an app bundle and a DMG or another centrally approved native distribution format. Unsigned, ad-hoc-signed, or unnotarized artifacts must be labeled accurately. Never expose certificates, private keys, passwords, or notarization credentials in source, logs, pull-request workflows, or artifacts. Never promote a prerelease to stable until the central release train records compatible tested versions.
