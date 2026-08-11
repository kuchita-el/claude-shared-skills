#!/usr/bin/env bash
# Claude/Codex marketplaceとplugin配布物の集合・manifestを双方向に検査する。
set -euo pipefail

root="${1:?usage: validate-plugin-manifests.sh <repo-root>}"
claude_marketplace="$root/.claude-plugin/marketplace.json"
codex_marketplace="$root/.agents/plugins/marketplace.json"
errors=0
fail() { printf '%s\n' "$1"; errors=$((errors + 1)); }

for file in "$claude_marketplace" "$codex_marketplace"; do
  if ! jq empty "$file" >/dev/null 2>&1; then fail "JSON不正: ${file#$root/}"; fi
done
[ "$errors" -eq 0 ] || exit 1

mapfile -t claude_names < <(jq -r '.plugins[]?.name // empty' "$claude_marketplace" | sort -u)
mapfile -t codex_names < <(jq -r '.plugins[]?.name // empty' "$codex_marketplace" | sort -u)
[ "${#claude_names[@]}" -gt 0 ] || fail "Claude marketplaceの対象pluginが0件"
[ "${#codex_names[@]}" -gt 0 ] || fail "Codex marketplaceの対象pluginが0件"

for name in "${claude_names[@]}"; do
  printf '%s\n' "${codex_names[@]}" | grep -Fxq "$name" || fail "Codex marketplaceに無い: $name"
done
for name in "${codex_names[@]}"; do
  printf '%s\n' "${claude_names[@]}" | grep -Fxq "$name" || fail "Claude marketplaceに無い: $name"
done

for name in "${claude_names[@]}"; do
  claude_path="$root/$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source' "$claude_marketplace")"
  codex_path="$root/$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source.path' "$codex_marketplace")"
  [ -d "$claude_path" ] || fail "Claude source pathが無い: $name"
  [ -d "$codex_path" ] || fail "Codex source pathが無い: $name"
  claude_manifest="$claude_path/.claude-plugin/plugin.json"
  codex_manifest="$codex_path/.codex-plugin/plugin.json"
  [ -f "$claude_manifest" ] || fail "Claude manifestが無い: $name"
  [ -f "$codex_manifest" ] || fail "Codex manifestが無い: $name"
  if [ -f "$claude_manifest" ] && [ -f "$codex_manifest" ]; then
    [ "$(jq -r .name "$claude_manifest")" = "$name" ] || fail "Claude manifest name不一致: $name"
    [ "$(jq -r .name "$codex_manifest")" = "$name" ] || fail "Codex manifest name不一致: $name"
    if [ "$(jq -r .version "$claude_manifest")" != "$(jq -r .version "$codex_manifest")" ]; then
      fail "version不一致: $name"
    fi
  fi
  [ -f "$claude_path/README.md" ] || fail "READMEが無い: $name"
  mapfile -t skills < <(find "$claude_path/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null | sort)
  collect_skill_names() {
    local plugin_path="$1" file relative
    while IFS= read -r file; do
      relative="${file#"$plugin_path/skills/"}"
      printf '%s\n' "${relative%/SKILL.md}"
    done < <(find "$plugin_path/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null | sort)
  }
  mapfile -t codex_skill_names < <(collect_skill_names "$codex_path")
  mapfile -t claude_skill_names < <(collect_skill_names "$claude_path")
  if [ "$(jq -r '.skills // empty' "$codex_manifest" 2>/dev/null)" = "./skills/" ]; then
    [ "${#skills[@]}" -gt 0 ] || fail "検査対象skillが0件: $name"
  fi
  if [ "$(printf '%s\n' "${claude_skill_names[@]}")" != "$(printf '%s\n' "${codex_skill_names[@]}")" ]; then
    fail "skill集合不一致: $name"
  fi
done

[ "$errors" -eq 0 ] || exit 1
printf 'checked=%s missing=0 errors=0\n' "${#claude_names[@]}"
