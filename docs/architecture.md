# macOS Architecture

## Current state

This repository is documentation-only. No application architecture has been instantiated and no product capability is claimed.

## Required boundaries

The future client will use SwiftUI for the application shell and normal views, with AppKit isolated to integrations or measured performance needs. UI state will be immutable where practical, work will use Swift concurrency, and blocking core polling, network, database, or document operations must remain off the main actor.

One tested bridge module will own the generated Swift wrapper and LinguaMesh Core XCFramework interaction. UI and platform-service layers must not call raw C functions throughout the application. Startup must negotiate core semantic, ABI, protocol, catalog, and feature versions and fail safely on incompatibility.

The client owns native lifecycle, navigation, accessibility, menus, shortcuts, file panels, drag-and-drop, clipboard, notifications, appearance, sandbox permissions, and credential resolution. Shared provider, routing, translation, document, persistence, and error-domain behavior remains in `linguamesh-core`.

## Security boundaries

Credentials must be stored in an application-specific Keychain namespace and supplied only for the requested operation. Persistent user-selected file access must use security-scoped bookmarks or URLs with balanced access lifetimes. Translation content must not enter normal logs or diagnostics. Signing and notarization material must remain outside the repository and outside untrusted CI.

Architectural changes affecting the ABI, protocol, sandbox, persistence ownership, or distribution model require a central compatibility decision before implementation.
