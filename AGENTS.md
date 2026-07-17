# macOS Repository Instructions

## Required reading

Before changing this repository, read `GLOBAL_GOAL.md`, `REPOSITORY_ROLE.md`, `IMPLEMENTATION_STATUS.md`, and the relevant local documentation. Read the authoritative `PROJECT_GOAL.md` from the sibling `linguamesh-project` repository when it is available, and verify its SHA-256 against `GLOBAL_GOAL.md`.

## Scope

This repository owns only the native macOS client, Apple platform services, application packaging, and macOS-specific tests. Shared translation, provider, persistence, document, and routing behavior belongs in `linguamesh-core`. Canonical UI strings belong in `linguamesh-l10n`.

Use current stable Swift with strict concurrency checking. Use SwiftUI for the application shell and normal views, and AppKit only when platform integration or measured performance requires it. Isolate all C interoperability in one tested core-bridge module. Use Keychain Services for credentials and security-scoped resources for persistent file access.

## Workflow

1. Inspect `git status --short --branch` and preserve unrelated changes.
2. State uncertain decisions with `Assumption:`.
3. Implement the smallest complete native behavior with tests.
4. Run every available check documented in `docs/testing.md`.
5. Update `IMPLEMENTATION_STATUS.md` with commands and results.
6. Update architecture, testing, and release documentation when behavior changes.

All code comments must be in Simplified Chinese on separate lines immediately above the code they describe. All console, log, diagnostic, and command-line output strings must be in English.

## Current commands

The repository is documentation-only. It has no dependency setup, formatter, product linter, test target, Xcode project, or build command. Run the exact foundation validation in `docs/testing.md`. Do not invent successful `swift`, `xcodebuild`, signing, notarization, or packaging results.

## Safety

Never commit credentials, signing identities, provisioning profiles, private keys, translated user content, or sensitive diagnostics. Do not weaken App Sandbox, hardened runtime, TLS, or Keychain protections to make a check pass. Never publish or label a release stable without compatible pinned core and localization versions plus reproducible evidence.
