#!/usr/bin/env bash
# tracked source/config/docsからplugins/<name>参照を収集し、台帳と双方向比較する。
set -euo pipefail
root="${1:?usage: validate-plugin-path-references.sh <repo-root> <ledger>}"
ledger="${2:?usage: validate-plugin-path-references.sh <repo-root> <ledger>}"
declare -A source=() listed=()
while IFS=: read -r file line rest; do
  file="${file#$root/}"
  plugin=$(printf '%s\n' "$rest" | grep -Eo 'plugins/(adr|dev-workflow|growth|writing)(/|$)' | head -1 | sed 's#/$##' || true)
  [ -n "$plugin" ] || continue
  source["$file:$line:$plugin"]=1
done < <({ find "$root/scripts" "$root/.claude-plugin" "$root/.agents" -type f 2>/dev/null; find "$root" -maxdepth 1 -type f; printf '%s\n' "$root/docs/development/test-execution.md" "$root/run-claude-local.sh" "$root/run-codex-local.sh"; } | grep -vF "$ledger" | grep -vF "$root/scripts/fixtures/" | xargs grep -HnE 'plugins/(adr|dev-workflow|growth|writing)(/|$|[^A-Za-z0-9_-])' || true)
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
