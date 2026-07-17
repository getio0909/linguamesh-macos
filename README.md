# LinguaMesh for macOS

LinguaMesh for macOS is the native SwiftUI and AppKit client for the LinguaMesh translation suite. This repository currently contains only its verified repository foundation. It does not yet contain an Xcode project, application source, tests, packages, or release artifacts.

## Project authority

- [`GLOBAL_GOAL.md`](GLOBAL_GOAL.md) pins the global specification revision.
- [`REPOSITORY_ROLE.md`](REPOSITORY_ROLE.md) defines this repository's ownership boundaries.
- [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md) records what is actually implemented and verified.

The authoritative specification lives in the sibling `linguamesh-project` repository. Product work must remain compatible with the pinned goal and a released LinguaMesh Core XCFramework.

## Intended native stack

The client will use current stable Swift, strict Swift concurrency, SwiftUI, and AppKit where profiling or platform integration justifies it. Credentials belong in Keychain Services, and persistent file access must use security-scoped resources. These are requirements, not claims of current implementation.

## Current validation

The foundation requires only Git and standard POSIX shell tools:

```sh
cd linguamesh-macos
git status --short --branch
git diff --check
```

The complete documentation check is in [`docs/testing.md`](docs/testing.md) and runs in [`.github/workflows/foundation.yml`](.github/workflows/foundation.yml). Product format, lint, test, and build commands are unavailable until the native project is implemented.

## Documentation

- [Architecture](docs/architecture.md)
- [Testing](docs/testing.md)
- [Releasing](docs/releasing.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

