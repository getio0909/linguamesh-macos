# Compatibility

Checkpoint: `M3-typed-host-secret-20260724`

Status: Development; macOS platform CI verified; release pending

| Component | Expected contract | Source revision | Verification |
| --- | --- | --- | --- |
| macOS client | `0.1.0-alpha.1` | `c528bfc` | Native CI `30095987188` passed Core XCFramework, strict Swift, 20 XCTest cases, app bundle, and ad-hoc signing smoke |
| Global goal | SHA-256 `11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198` | `b75d4d1df2adbb3729db9425f7b999f62673e22c` | Exact digest verified locally |
| LinguaMesh Core | `0.1.0-alpha.2`, ABI major `1`, protocol `1` | `b39dbdc2877a60c6666697cc0817f31225496cb2` | ABI 1 typed secret event/response contract pinned; short-text chunking regression fixed |
| Localization | `0.1.0`, platform resource contract `1`, development | `7e8c987737444d4e0f8f2642b108eee4c7801f58` | Exact XCStrings SHA-256 verified locally |

The committed `Localizable.xcstrings` SHA-256 for this checkpoint is `19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36`. It must match `linguamesh-l10n/generated/macos/Localizable.xcstrings` byte for byte.

Startup currently rejects unknown ABI or protocol versions through the generated Swift wrapper. Core semantic version, provider catalog version, enabled feature negotiation, generated typed Swift protocol messages, and immutable artifact checksums are not exposed by protocol version 1. The source dependency is pinned to an immutable commit for CI, but a release must use a verified immutable artifact and checksum from the central `release-manifest.toml` before any compatibility or stable claim.

Rollback for this development checkpoint is to the previous documentation-only macOS revision. No database migration, released artifact, persisted provider profile, or external service state is introduced.
