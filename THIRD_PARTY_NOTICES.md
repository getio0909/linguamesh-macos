# Third-Party Notices

The repository does not commit a third-party binary artifact, image, font, or provider logo. The build consumes the first-party MIT-licensed LinguaMesh Core Swift package and generated XCFramework from the sibling `linguamesh-core` repository. It also consumes first-party generated localization data from `linguamesh-l10n`.

GitHub Actions uses `actions/checkout` and `dtolnay/rust-toolchain` under their published upstream licenses. They are CI infrastructure and are not distributed as part of the application.

The application links Apple-provided SwiftUI, AppKit, Foundation, Security, and system runtime components under the Apple platform SDK terms. Tests launch Python 3 and use only its standard library to host a loopback fake provider; Python is not bundled with the application.

Before adding a dependency or distributable asset, record its name, version, source, license, purpose, modification status, and distribution obligations here. Review transitive dependencies and avoid AGPL, SSPL, non-commercial, source-available, or otherwise incompatible terms. Apple SDK components must not be copied into the repository.

Notices, source revision, checksum, SBOM, and license metadata for a pinned LinguaMesh Core XCFramework and localization bundle must be incorporated before any application artifact is distributed.
