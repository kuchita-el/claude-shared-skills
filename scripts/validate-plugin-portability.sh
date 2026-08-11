#!/usr/bin/env bash
# compatibility matrix / permission ledger / skill参照境界を検査する。
set -euo pipefail
root="${1:?usage: validate-plugin-portability.sh <repo-root>}"
errors=0
fail() { printf '%s\n' "$1"; errors=$((errors + 1)); }

compat="$root/docs/references/cross-host-compatibility.json"
ledger="$root/docs/references/cross-host-permission-ledger.json"
if [ -f "$root/compatibility.json" ]; then compat="$root/compatibility.json"; fi
if [ -f "$root/permission-ledger.json" ]; then ledger="$root/permission-ledger.json"; fi
for file in "$compat" "$ledger"; do [ -f "$file" ] || { fail "schemaが無い: ${file#$root/}"; continue; }; jq empty "$file" >/dev/null 2>&1 || fail "JSON不正: ${file#$root/}"; done

compat_rows=()
if [ -f "$compat" ]; then mapfile -t compat_rows < <(jq -c '.[]?' "$compat" 2>/dev/null || true); fi
[ "${#compat_rows[@]}" -gt 0 ] || fail "compatibility matrixが0件"
fixture_root="$root/scripts/fixtures/skill-portability"
[ "$compat" != "$root/docs/references/cross-host-compatibility.json" ] &&
  [ -d "$root/scripts/fixtures/writing" ] && fixture_root="$root/scripts/fixtures"
for row in "${compat_rows[@]}"; do
  jq -e '(.feature|type == "string" and length > 0)' <<<"$row" >/dev/null || fail "compatibility: missing feature"
  for key in claudeLevel codexLevel; do
    jq -e --arg k "$key" '(.[$k]|type == "string" and length > 0)' <<<"$row" >/dev/null || fail "compatibility: missing $key"
  done
  jq -e '(.fixtures|type == "array" and length > 0 and all(.[]; type == "string" and length > 0))' <<<"$row" >/dev/null || fail "compatibility: missing fixtures"
  while IFS= read -r level; do
    case "$level" in portable|adapted|degraded|surface-specific) ;; *) fail "compatibility: invalid level $level";; esac
  done < <(jq -r '.claudeLevel,.codexLevel' <<<"$row")
  if jq -e '.claudeLevel == "degraded" or .claudeLevel == "surface-specific" or .codexLevel == "degraded" or .codexLevel == "surface-specific"' <<<"$row" >/dev/null; then
    jq -e '(.residualRisk|type == "string" and length > 0)' <<<"$row" >/dev/null || fail "compatibility: missing residualRisk"
  elif jq -e 'has("residualRisk")' <<<"$row" >/dev/null; then
    jq -e '(.residualRisk|type == "string")' <<<"$row" >/dev/null || fail "compatibility: invalid residualRisk"
  fi
  if [ -d "$fixture_root" ]; then
    while IFS= read -r fixture; do
      [ -d "$fixture_root/$fixture" ] || fail "compatibility: fixtureが無い $fixture"
    done < <(jq -r '.fixtures[]' <<<"$row")
  fi
done
if [ -f "$ledger" ]; then
  while IFS= read -r row; do
    for key in permission requiredOperation witness narrowerAlternative verdict; do jq -e --arg k "$key" '.[$k] != null and (.[$k]|strings|length)>0' <<<"$row" >/dev/null || fail "permission-ledger: missing $key"; done
    case "$(jq -r .verdict <<<"$row")" in necessary|optional|degraded) ;; *) fail "permission-ledger: invalid verdict";; esac
  done < <(jq -c '.[]' "$ledger" 2>/dev/null || true)
fi

skills=()
while IFS= read -r -d '' file; do skills+=("$file"); done < <(find "$root/plugins" -path '*/skills/*/SKILL.md' -print0 2>/dev/null)
[ "${#skills[@]}" -gt 0 ] || fail "検査対象skillが0件"
for skill in "${skills[@]}"; do
  body=$(sed '1,/^---$/d' "$skill")
  # SKILLからreferenceへのパスが存在するか、referenceからreferenceへのedgeを報告する。
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    skill_plugin_root="$(dirname "$(dirname "$(dirname "$skill")")")"
    target="$(dirname "$skill")/$ref"
    [ -e "$target" ] || target="$skill_plugin_root/$ref"
    [ -e "$target" ] || fail "壊れた参照: ${skill#$root/} -> $ref"
    if [ -f "$target" ]; then
      while IFS= read -r nested; do
        nested_base="$(basename "$nested")"
        grep -Fq "$nested_base" <<<"$body" || fail "2段参照: ${skill#$root/} -> $ref -> $nested"
      done < <(grep -Eo '(skills/[A-Za-z0-9_./-]+/)?references/[A-Za-z0-9_./-]+' "$target" | sort -u || true)
    fi
  done < <(printf '%s\n' "$body" | grep -Eo '(skills/[A-Za-z0-9_./-]+/)?references/[A-Za-z0-9_./-]+' | sort -u || true)
  # plugin rootから配布元側へ戻る相対参照を拒否する。
  printf '%s\n' "$body" | grep -Eq '(^|[[:space:]`(])\.\./(\.\./)*packages/|(^|[[:space:]`(])\.\./(\.\./)*dist/' && fail "配布元への逆参照: ${skill#$root/}" || true
done
[ "$errors" -eq 0 ] || exit 1
printf 'checked=%s errors=0\n' "${#skills[@]}"
