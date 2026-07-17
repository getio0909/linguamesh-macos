# Releasing

## Current state

No application target or distributable artifact exists. This foundation must not be tagged or published as a product release, and no signing or notarization claim is valid.

## Future release gate

A macOS release may be prepared only after:

1. the application and tests pass with documented Xcode and Swift versions;
2. the embedded LinguaMesh Core XCFramework, ABI, protocol, catalog, and localization versions match the central release manifest;
3. entitlements, App Sandbox permissions, Keychain access, security-scoped resources, accessibility, migrations, and packaging smoke tests are verified;
4. third-party notices, license review, privacy/security review, changelog, checksum, and rollback information are complete;
5. signing and notarization run only in protected release infrastructure and produce verifiable evidence.

The intended deliverables are an app bundle and a DMG or another centrally approved native distribution format. Unsigned or unnotarized artifacts must be labeled accurately. Never expose certificates, private keys, passwords, or notarization credentials in source, logs, pull-request workflows, or artifacts. Never promote a prerelease to stable until the central release train records compatible tested versions.
