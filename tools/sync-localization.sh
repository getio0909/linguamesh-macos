#!/usr/bin/env bash
set -euo pipefail

# 从仓库根目录解析受版本控制的资源和规范来源。
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_catalog="$repo_root/../linguamesh-l10n/generated/macos/Localizable.xcstrings"
target_catalog="$repo_root/Sources/LinguaMeshFeature/Resources/Localizable.xcstrings"
expected_revision='7e8c987737444d4e0f8f2642b108eee4c7801f58'
expected_catalog_digest='19b951925b7c676f42b84d7880c0d9c5383289c48920de5cf2611dbe8d7cad36'
mode="${1:---check}"

test -s "$source_catalog" || {
    printf '%s\n' 'Generated macOS localization catalog is unavailable.' >&2
    exit 1
}

actual_revision="$(git -C "$repo_root/../linguamesh-l10n" rev-parse HEAD)"
test "$actual_revision" = "$expected_revision" || {
    printf '%s\n' 'Localization source revision does not match the compatibility pin.' >&2
    exit 1
}

if command -v sha256sum >/dev/null; then
    actual_catalog_digest="$(sha256sum "$source_catalog" | awk '{print $1}')"
else
    actual_catalog_digest="$(shasum -a 256 "$source_catalog" | awk '{print $1}')"
fi
test "$actual_catalog_digest" = "$expected_catalog_digest" || {
    printf '%s\n' 'Localization catalog digest does not match the compatibility pin.' >&2
    exit 1
}

case "$mode" in
    --check)
        cmp -s "$source_catalog" "$target_catalog" || {
            printf '%s\n' 'Committed localization resources are stale.' >&2
            exit 1
        }
        printf '%s\n' 'Localization resources are synchronized.'
        ;;
    --update)
        install -m 0644 "$source_catalog" "$target_catalog"
        printf '%s\n' 'Localization resources were updated.'
        ;;
    *)
        printf 'Unsupported mode: %s\n' "$mode" >&2
        exit 2
        ;;
esac
