# Repository Role

## Purpose

`linguamesh-macos` delivers the native macOS application for LinguaMesh.

## This repository owns

- SwiftUI application shell and native macOS user experience.
- AppKit integrations needed for high-volume editors, menus, tables, and platform services.
- macOS lifecycle, accessibility, appearance, clipboard, drag-and-drop, file panels, notifications, and sandbox behavior.
- Keychain-backed credential resolution and security-scoped file access.
- The generated Swift wrapper's client-side integration with a pinned LinguaMesh Core XCFramework.
- macOS tests, app bundle configuration, entitlements, packaging, signing guidance, and notarization guidance.

## This repository does not own

- Provider adapters, routing, prompt construction, document codecs, shared persistence, or translation logic; those belong in `linguamesh-core`.
- Canonical localization source or generators; those belong in `linguamesh-l10n`.
- Cross-repository compatibility and release-train authority; those belong in `linguamesh-project`.

The client must reject an incompatible core ABI or protocol version and must never silently duplicate shared behavior.
