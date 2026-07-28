# Compatibility

Checkpoint: `M3-typed-host-secret-20260724`

Status: Development; macOS platform CI verified for the current Core descendant; release pending

## 2026-07-24 Core VFS-descendant compatibility checkpoint

Assumption: Core `9e69d01cbae1ca0421923e059aa3252c4ecbe1be` changes Linux-only storage coverage
without changing the ABI-1 typed host-secret contract consumed by macOS. Hosted workflow
`30101369965` verified the exact XCFramework and client checks.

| Component | Expected contract | Source revision | Verification |
| --- | --- | --- | --- |
| macOS client | `0.1.0-alpha.1` | `afc80dc0b76f8fc45be641065c703929bbcac552` | Native CI `30101369965` passed exact Core XCFramework, strict Swift, unit/integration tests, app bundle, and ad-hoc signing smoke |
| Global goal | SHA-256 `11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198` | `44068ddd750282e9ffa69c9816b4361ac1858641` | Exact digest verified locally |
| LinguaMesh Core | `0.1.0-alpha.2`, ABI major `1`, protocol `1` | `cb061d24a3e0c4059a65d099d30bc643e9e079ea` | ABI 1 typed secret event/response contract pinned; Linux-only VFS descendant pending hosted macOS verification |
| Localization | `0.1.0`, platform resource contract `1`, development | `43f5a6f069f6d0e6d075517b0c017784fe505b0d` | Exact XCStrings SHA-256 verified locally |

The committed `Localizable.xcstrings` SHA-256 for this checkpoint is `19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36`. It must match `linguamesh-l10n/generated/macos/Localizable.xcstrings` byte for byte.

Startup currently rejects unknown ABI or protocol versions through the generated Swift wrapper. Core semantic version, provider catalog version, enabled feature negotiation, generated typed Swift protocol messages, and immutable artifact checksums are not exposed by protocol version 1. The source dependency is pinned to an immutable commit for CI, but a release must use a verified immutable artifact and checksum from the central `release-manifest.toml` before any compatibility or stable claim.

Rollback for this development checkpoint is to the previous documentation-only macOS revision. No database migration, released artifact, persisted provider profile, or external service state is introduced.
