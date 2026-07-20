#!/usr/bin/env bash
set -euo pipefail

# 仅组装未签名的本地应用包；签名和公证属于受保护发布流程。
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for required_tool in swift plutil; do
    command -v "$required_tool" >/dev/null || {
        printf 'Required tool is unavailable: %s\n' "$required_tool" >&2
        exit 1
    }
done

swift build \
    --configuration release \
    -Xswiftc -warnings-as-errors \
    -Xswiftc -strict-concurrency=complete
bin_path="$(swift build --configuration release --show-bin-path)"
executable="$bin_path/LinguaMesh"
test -x "$executable" || {
    printf '%s\n' 'Release executable was not produced.' >&2
    exit 1
}

app_path="$repo_root/dist/LinguaMesh.app"
rm -rf -- "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
install -m 0755 "$executable" "$app_path/Contents/MacOS/LinguaMesh"
plutil -convert binary1 -o "$app_path/Contents/Info.plist" Packaging/Info.plist

resource_bundle="$(find "$bin_path" -maxdepth 1 -type d -name '*LinguaMeshFeature*.bundle' -print -quit)"
test -n "$resource_bundle" || {
    printf '%s\n' 'Swift package resource bundle was not produced.' >&2
    exit 1
}
cp -R "$resource_bundle" "$app_path/Contents/Resources/"

plutil -lint "$app_path/Contents/Info.plist"
printf '%s\n' 'Unsigned application bundle assembled for smoke testing.'
