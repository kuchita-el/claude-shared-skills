#!/usr/bin/env bash
# plugin配下の差分とmanifest version bumpの整合を検査する。
set -euo pipefail

base_ref="${1:?usage: validate-plugin-versions.sh <base-ref> [changed-paths-file]}"
root="${PLUGIN_REPO_ROOT:-.}"
if [ -n "${2:-}" ]; then mapfile -t changed <"$2"; else mapfile -t changed < <(git diff --name-only "$base_ref" -- 'plugins/*'); fi
declare -A touched=()
for path in "${changed[@]}"; do [[ "$path" == plugins/* ]] && touched["${path#plugins/}"]="${path#plugins/}"; done
errors=0
for name in $(printf '%s\n' "${!touched[@]}" | cut -d/ -f1 | sort -u); do
  [ -n "$name" ] || continue
  current="$root/plugins/$name/.claude-plugin/plugin.json"
  codex="$root/plugins/$name/.codex-plugin/plugin.json"
  [ -f "$current" ] && [ -f "$codex" ] || { echo "manifestが無い: $name"; errors=$((errors+1)); continue; }
  current_version=$(jq -r .version "$current")
  codex_version=$(jq -r .version "$codex")
  [ "$current_version" = "$codex_version" ] || { echo "version不一致: $name"; errors=$((errors+1)); }
  baseline_claude=""; baseline_codex=""
  if git rev-parse --verify "$base_ref:$current" >/dev/null 2>&1; then baseline_claude=$(git show "$base_ref:$current" | jq -r .version); fi
  if git rev-parse --verify "$base_ref:$codex" >/dev/null 2>&1; then baseline_codex=$(git show "$base_ref:$codex" | jq -r .version); fi
  if [ -f "$root/.baseline-versions.json" ]; then
    baseline_claude=$(jq -r --arg n "$name" '.[$n] // empty' "$root/.baseline-versions.json")
    baseline_codex="$baseline_claude"
  fi
  if [ -n "$baseline_claude" ] && [ "$baseline_claude" = "$current_version" ] && [ "$baseline_codex" = "$codex_version" ]; then echo "version据え置き: $name ($current_version)"; errors=$((errors+1)); fi
done
[ "$errors" -eq 0 ]
