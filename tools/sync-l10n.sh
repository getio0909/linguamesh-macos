#!/usr/bin/env bash
set -euo pipefail

# 为跨仓库自动化提供稳定的本地化同步入口。
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$repo_root/tools/sync-localization.sh" "$@"
