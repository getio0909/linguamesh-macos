# Compatibility

Checkpoint: `M3-typed-host-secret-20260724`

Status: Development; macOS platform CI pending for the current Core descendant; release pending

## 2026-07-24 Core VFS-descendant compatibility checkpoint

Assumption: Core `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` changes Linux-only storage coverage
without changing the ABI-1 typed host-secret contract consumed by macOS. The exact XCFramework
rebuild and macOS client checks must be verified by hosted CI before this pin is treated as current.

| Component | Expected contract | Source revision | Verification |
| --- | --- | --- | --- |
| macOS client | `0.1.0-alpha.1` | `c528bfc` | Native CI `30095987188` passed Core XCFramework, strict Swift, 20 XCTest cases, app bundle, and ad-hoc signing smoke |
| Global goal | SHA-256 `11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198` | `b75d4d1df2adbb3729db9425f7b999f62673e22c` | Exact digest verified locally |
| LinguaMesh Core | `0.1.0-alpha.2`, ABI major `1`, protocol `1` | `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` | ABI 1 typed secret event/response contract pinned; Linux-only VFS descendant pending hosted macOS verification |
| Localization | `0.1.0`, platform resource contract `1`, development | `7fd210692bb269ef52f7453bfeb2b0f0759b1d4c` | Exact XCStrings SHA-256 verified locally |

The committed `Localizable.xcstrings` SHA-256 for this checkpoint is `19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36`. It must match `linguamesh-l10n/generated/macos/Localizable.xcstrings` byte for byte.

Startup currently rejects unknown ABI or protocol versions through the generated Swift wrapper. Core semantic version, provider catalog version, enabled feature negotiation, generated typed Swift protocol messages, and immutable artifact checksums are not exposed by protocol version 1. The source dependency is pinned to an immutable commit for CI, but a release must use a verified immutable artifact and checksum from the central `release-manifest.toml` before any compatibility or stable claim.

Rollback for this development checkpoint is to the previous documentation-only macOS revision. No database migration, released artifact, persisted provider profile, or external service state is introduced.
