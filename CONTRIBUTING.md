# Contributing

## Before starting

Read `GLOBAL_GOAL.md`, `REPOSITORY_ROLE.md`, `AGENTS.md`, and `IMPLEMENTATION_STATUS.md`. Confirm that the proposed behavior belongs in the macOS client rather than the shared core or localization repository. Open an architectural discussion before changing the core ABI, protocol, security boundary, packaging model, or supported macOS baseline.

## Changes

- Preserve unrelated work and keep each change narrowly scoped.
- Use native SwiftUI/AppKit patterns and keep provider or document logic out of the client.
- Add tests with behavior changes; do not submit static mock UI as completed behavior.
- Record new dependencies with purpose, maintenance status, license, and distribution impact.
- Keep code comments in Simplified Chinese on separate lines above the described code; keep console and diagnostic strings in English.
- Never commit credentials, signing assets, user documents, or sensitive diagnostics.

Use short imperative commit subjects, optionally scoped, such as `docs: define macOS release prerequisites`. A pull request must describe scope, linked issues or decisions, core/localization compatibility, security and rollback impact, and the exact validation commands and results. Include screenshots or accessibility evidence for visible UI changes.

## Validation

Run the complete current foundation check in `docs/testing.md`. Product format, lint, test, and build commands do not exist yet and must not be reported as run. Once native targets are introduced, update `docs/testing.md` and CI in the same change.

