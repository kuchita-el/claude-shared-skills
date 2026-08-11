#!/usr/bin/env bash
# tracked source/config/docsからplugins/<name>参照を収集し、台帳と双方向比較する。
set -euo pipefail
root="${1:?usage: validate-plugin-path-references.sh <repo-root> <ledger>}"
ledger="${2:?usage: validate-plugin-path-references.sh <repo-root> <ledger>}"
declare -A source=() listed=()
plugin_names=()
while IFS= read -r name; do plugin_names+=("$name"); done < <(find "$root/plugins" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)
if [ "${#plugin_names[@]}" -eq 0 ]; then
  while IFS= read -r row; do
    IFS='|' read -r _ _ _ plugin _ <<<"$row"
    plugin="${plugin##*/}"
    [ -n "$plugin" ] && plugin_names+=("$plugin")
  done < <(grep -E '^\|.*\|.*\|[[:space:]]*plugins/' "$ledger" 2>/dev/null || true)
fi
plugin_pattern=""
for name in "${plugin_names[@]}"; do plugin_pattern+="${plugin_pattern:+|}$name"; done
[ -n "$plugin_pattern" ] || { echo "plugin集合が0件"; exit 1; }
while IFS=: read -r file line rest; do
  file="${file#$root/}"
  plugin=""
  token=$(printf '%s\n' "$rest" | grep -Eo 'plugins/[A-Za-z0-9._-]+' | head -1 || true)
  for name in "${plugin_names[@]}"; do [ "$token" = "plugins/$name" ] && plugin="$token"; done
  [ -n "$plugin" ] || continue
  source["$file:$line:$plugin"]=1
done < <({ find "$root/scripts" "$root/.claude-plugin" "$root/.agents" -type f 2>/dev/null; find "$root" -maxdepth 1 -type f; printf '%s\n' "$root/docs/development/test-execution.md" "$root/run-claude-local.sh" "$root/run-codex-local.sh"; } | grep -vF "$ledger" | grep -vF "$root/scripts/fixtures/" | xargs -r grep -HnE 'plugins/[A-Za-z0-9._-]+' 2>/dev/null || true)
while IFS= read -r row; do
  IFS='|' read -r _ path line plugin _ <<<"$row"
  path="$(printf '%s' "$path" | sed 's/^ *//;s/ *$//')"
  line="$(printf '%s' "$line" | sed 's/^ *//;s/ *$//')"
  plugin="$(printf '%s' "$plugin" | sed 's/^ *//;s/ *$//')"
  key="${path}:${line}:${plugin}"
  [[ "$line" =~ ^[0-9]+$ && "$plugin" =~ ^plugins/[A-Za-z0-9._-]+$ ]] || key=""
  [ -n "$key" ] && listed["$key"]=1
done < <(grep -E '^\|.*\|.*\|[[:space:]]*plugins/[A-Za-z0-9._-]+[[:space:]]*\|' "$ledger" 2>/dev/null || true)
missing=0
for key in "${!source[@]}"; do [ "${listed[$key]+x}" ] || { echo "unregistered: $key"; missing=$((missing+1)); }; done
stale=0
for key in "${!listed[@]}"; do [ "${source[$key]+x}" ] || { echo "stale-ledger: $key"; stale=$((stale+1)); }; done
[ $((missing + stale)) -eq 0 ] || exit 1
[ "${#source[@]}" -gt 0 ] || { echo "参照が0件"; exit 1; }
printf 'checked=%s missing=0 stale=0\n' "${#source[@]}"
