# Security Policy

## Reporting a vulnerability

Do not disclose suspected vulnerabilities in a public issue. Use this repository's private GitHub security-advisory channel when it is enabled. If it is unavailable, follow the private reporting route documented by the central `linguamesh-project` security policy. Include affected revisions, reproduction details, impact, and a safe contact method. Do not include live credentials or private user documents.

## Supported versions

This repository has no released application version. The prerelease source slice receives maintenance, but there is currently no product binary to classify as supported.

## Security requirements

- Store provider credentials through Keychain Services; persist only core-defined secret references outside Keychain.
- Keep translation content, authorization headers, cookies, signed URLs, signing keys, and provisioning material out of source, logs, diagnostics, tests, and CI artifacts.
- Require HTTPS for remote endpoints. Loopback HTTP is allowed only under the global policy.
- Treat provider output, source documents, locale data, file paths, and protocol messages as untrusted input.
- Preserve App Sandbox, hardened runtime, security-scoped access, explicit file ownership, and core compatibility checks.
- Never provide signing or notarization secrets to untrusted pull-request workflows.

The current core protocol cannot request a stored credential. Keychain persistence is implemented, but authenticated translation remains disabled until a typed one-time secret host-response flow exists and is tested. Do not work around this gap by reading credentials into preferences, command messages, logs, or diagnostics.

Security-sensitive changes require focused tests, threat-model review, and explicit evidence in `IMPLEMENTATION_STATUS.md`.
