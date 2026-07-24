#!/usr/bin/env bash
set -euo pipefail

# 将检查限定到当前仓库和明确的同级合同文件。
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for required_tool in awk cmp find git rg; do
    command -v "$required_tool" >/dev/null || {
        printf 'Required tool is unavailable: %s\n' "$required_tool" >&2
        exit 1
    }
done

required_files=(
    COMPATIBILITY.md
    Package.swift
    Sources/LinguaMeshApp/LinguaMeshApp.swift
    Sources/LinguaMeshFeature/CoreBridge/NativeCoreClient.swift
    Sources/LinguaMeshFeature/Platform/CredentialStore.swift
    Sources/LinguaMeshFeature/Resources/Localizable.xcstrings
    Packaging/Info.plist
    Packaging/LinguaMesh.entitlements
    Tests/LinguaMeshFeatureTests/Fixtures/fake_provider.py
)
for file in "${required_files[@]}"; do
    test -s "$file" || {
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    }
done

expected_goal='11f9a65927aac7e57e2af119e9d21cc98e8d5a08b8a112a19ee1c47903e36198'
expected_project_revision='b75d4d1df2adbb3729db9425f7b999f62673e22c'
expected_core_revision='9e69d01cbae1ca0421923e059aa3252c4ecbe1be'
git -C ../linguamesh-project merge-base --is-ancestor "$expected_project_revision" HEAD || {
    printf '%s\n' 'Project checkout does not contain the compatibility-pinned revision.' >&2
    exit 1
}
if command -v sha256sum >/dev/null; then
    actual_goal="$(sha256sum ../linguamesh-project/PROJECT_GOAL.md | awk '{print $1}')"
else
    actual_goal="$(shasum -a 256 ../linguamesh-project/PROJECT_GOAL.md | awk '{print $1}')"
fi
test "$actual_goal" = "$expected_goal" || {
    printf '%s\n' 'Pinned global goal digest does not match.' >&2
    exit 1
}

actual_core_revision="$(git -C ../linguamesh-core rev-parse HEAD)"
test "$actual_core_revision" = "$expected_core_revision" || {
    printf '%s\n' 'Core checkout does not match the compatibility pin.' >&2
    exit 1
}
test -z "$(git -C ../linguamesh-core status --porcelain)" || {
    printf '%s\n' 'Core checkout contains uncommitted source changes.' >&2
    exit 1
}
rg -q '^#define LM_ABI_VERSION_MAJOR UINT32_C\(1\)$' \
    ../linguamesh-core/contracts/abi/linguamesh.h || {
    printf '%s\n' 'Pinned core header does not declare ABI major 1.' >&2
    exit 1
}
rg -q '^    public static let abiVersionMajor: UInt32 = 1$' \
    ../linguamesh-core/bindings/apple/Sources/LinguaMeshCore/LinguaMeshCore.swift || {
    printf '%s\n' 'Pinned Swift wrapper does not declare ABI major 1.' >&2
    exit 1
}
rg -q 'lm_engine_buffer_free\(current, &buffer\)' \
    ../linguamesh-core/bindings/apple/Sources/LinguaMeshCore/LinguaMeshCore.swift || {
    printf '%s\n' 'Pinned Swift wrapper does not use engine-bound buffer release.' >&2
    exit 1
}
rg -q 'case \.resourceExhausted:' \
    Sources/LinguaMeshFeature/CoreBridge/NativeCoreClient.swift || {
    printf '%s\n' 'Client does not map the ABI 1 resource-exhaustion result.' >&2
    exit 1
}

bash tools/sync-l10n.sh --check

if rg -n 'uses:[[:space:]]+[^[:space:]@]+@(v[0-9]+|main|master|latest)$' .github/workflows; then
    printf '%s\n' 'Mutable GitHub Action reference detected.' >&2
    exit 1
fi

if rg -n '\blm_[[:alnum:]_]+' Sources; then
    printf '%s\n' 'Raw C ABI usage escaped the generated Swift wrapper boundary.' >&2
    exit 1
fi

if rg -n '^[[:space:]]*//[/]?[[:space:]]*[A-Za-z]' Sources Tests; then
    printf '%s\n' 'English code comment detected.' >&2
    exit 1
fi

if rg -n '[^[:space:]][[:space:]]+//' Sources Tests; then
    printf '%s\n' 'Inline code comment detected.' >&2
    exit 1
fi

credential_pattern='(github_[p]at_|[g]hp_[[:alnum:]]{20,}|[s]k-[[:alnum:]_-]{20,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE [K]EY-----)'
if rg -l -I --hidden \
    --glob '!.git/**' \
    --glob '!tools/check-source.sh' \
    "$credential_pattern" .; then
    printf '%s\n' 'Credential signature detected.' >&2
    exit 1
fi

if find Sources Tests Packaging tools .github -type f \
    \( -name '*.swift' -o -name '*.py' -o -name '*.sh' -o -name '*.md' -o -name '*.yml' -o -name '*.plist' \) \
    -exec awk '/[[:blank:]]$/ { printf "%s:%d: trailing whitespace\n", FILENAME, FNR; bad=1 } END { exit bad }' {} +; then
    printf '%s\n' 'Source hygiene validation passed.'
else
    exit 1
fi

git diff --check
