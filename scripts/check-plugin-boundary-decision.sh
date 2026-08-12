#!/usr/bin/env bash
set -euo pipefail
root="${1:?usage: check-plugin-boundary-decision.sh <repo-root> <ledger.md|ledger.json>}"
ledger="${2:?usage: check-plugin-boundary-decision.sh <repo-root> <ledger.md|ledger.json>}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
json="$ledger"
if [[ "$ledger" == *.md ]]; then
  awk '/^```boundary-decision-json$/{inside=1; next} /^```$/{if(inside){exit}} inside{print}' "$ledger" >"$tmp/ledger.json"
  json="$tmp/ledger.json"
fi
fail() { printf '%s\n' "$1" >&2; exit 1; }
[ -s "$json" ] || fail "決定台帳が無い: ${ledger#$root/}"
jq empty "$json" >/dev/null 2>&1 || fail "決定台帳JSONが不正"
expected_ids='["dependency-insight","domain-design"]'
actual_ids=$(jq -c '[.candidates[]?.id] | sort' "$json")
[ "$actual_ids" = "$expected_ids" ] || fail "候補集合不一致: $actual_ids"
expected_checks='["definitionsSelfContained","distributionReferencesResolve","isolatedFixturePass","noAgentDependency","noSharedRuleCopy","noSourceDataDependency","referenceDepthOne"]'
for candidate in domain-design dependency-insight; do
  row=$(jq -c --arg id "$candidate" '.candidates[] | select(.id == $id)' "$json")
  [ -n "$row" ] || fail "候補が無い: $candidate"
  checks=$(jq -c '[.checks[]?.id] | sort' <<<"$row")
  [ "$checks" = "$expected_checks" ] || fail "判定項目集合不一致: $candidate"
  [ "$(jq '.checks | length' <<<"$row")" -eq 7 ] || fail "判定項目数不一致: $candidate"
  while IFS= read -r check; do
    id=$(jq -r .id <<<"$check"); value=$(jq -r .value <<<"$check")
    case "$value" in pass|fail) ;; *) fail "未判定: $candidate/$id" ;; esac
    jq -e '.evidence | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)' <<<"$check" >/dev/null || fail "evidenceが無い: $candidate/$id"
  done < <(jq -c '.checks[]' <<<"$row")
  derived=split; jq -e '.checks | any(.[]; .value == "fail")' <<<"$row" >/dev/null && derived=retain
  [ "$(jq -r .decision <<<"$row")" = "$derived" ] || fail "decision-mismatch: $candidate"
  expected_approval=J1; [ "$candidate" = dependency-insight ] && expected_approval=J2
  [ "$(jq -r .approval.id <<<"$row")" = "$expected_approval" ] || fail "approval-mismatch: $candidate"
  [ "$(jq -r .approval.status <<<"$row")" = approved ] || fail "承認未了: $candidate"
done
declare -a actual_graph=()
for candidate in domain-design dependency-insight; do
  case "$candidate" in domain-design) plugin=domain-design; skills=(event-storming domain-modeling);; dependency-insight) plugin=dependency-insight; skills=(dependency-check);; esac
  for skill in "${skills[@]}"; do
    dir="$root/plugins/$plugin/skills/$skill"; [ -d "$dir" ] || continue
    [ "$(find "$dir" -type f | wc -l)" -gt 0 ] || fail "検査対象skillが0件: $candidate/$skill"
    while IFS= read -r ref; do
      target="$dir/$ref"; [ -e "$target" ] || fail "壊れた参照: ${dir#$root/} -> $ref"
      actual_graph+=("$candidate|${dir#$root/}/SKILL.md|outbound|${target#$root/}")
    done < <(rg -o '\$\{CLAUDE_SKILL_DIR\}/references/[A-Za-z0-9_./-]+' "$dir/SKILL.md" | sed 's#.*references/#references/#' | sort -u || true)
    rg -n '(^|[^a-z])agents/|docs/behavior-invariants' "$dir" >/dev/null && fail "共有またはagent依存: $candidate/$skill" || true
  done
done
[ "${#actual_graph[@]}" -gt 0 ] || fail "実参照グラフが0件"
mapfile -t ledger_graph < <(jq -r '.graph[] | [.candidate,.path,.direction,.target] | join("|")' "$json" | sort)
mapfile -t actual_sorted < <(printf '%s\n' "${actual_graph[@]}" | sort)
[ "${ledger_graph[*]-}" = "${actual_sorted[*]-}" ] || fail "graph差分: ledger=${#ledger_graph[@]} actual=${#actual_sorted[@]}"
printf 'boundary decision valid: candidates=2 graph=%s\n' "${#actual_graph[@]}"
