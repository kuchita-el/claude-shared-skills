#!/usr/bin/env bash
# このリポジトリのプラグインをローカルで読み込んでClaude Codeを起動する
set -euo pipefail
cd "$(dirname "$0")"

mapfile -t plugin_dirs < <(jq -r '.plugins[]?.source // empty' .claude-plugin/marketplace.json)
[ "${#plugin_dirs[@]}" -gt 0 ] || { echo "Claude marketplaceの対象pluginが0件" >&2; exit 1; }
args=()
for plugin_dir in "${plugin_dirs[@]}"; do args+=(--plugin-dir "$plugin_dir"); done
exec claude "${args[@]}" "$@"
