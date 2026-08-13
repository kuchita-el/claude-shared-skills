#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: $0 validate|emit-actions <ledger.md> <boundary.json|md> [actions.json]" >&2; exit 2; }
mode="${1:-}"; ledger_file="${2:-}"; boundary_file="${3:-}"
[ -n "$mode" ] && [ -n "$ledger_file" ] && [ -n "$boundary_file" ] || usage
extract_json() {
  local file="$1" marker="$2" fence
  fence=$(printf '\x60\x60\x60')
  if jq empty "$file" >/dev/null 2>&1; then cat "$file"; return; fi
  awk -v marker="$marker" -v fence="$fence" 'index($0, fence marker) {inside=1; next} inside && index($0, fence) == 1 {exit} inside {print}' "$file"
}
ledger_json=$(extract_json "$ledger_file" migration-ledger-json)
boundary_json=$(extract_json "$boundary_file" boundary-decision-json)
printf '%s' "$ledger_json" | jq empty >/dev/null 2>&1 || { echo "migration ledger JSON不正"; exit 1; }
printf '%s' "$boundary_json" | jq empty >/dev/null 2>&1 || { echo "boundary decision JSON不正"; exit 1; }
tmp_dir=$(mktemp -d); trap 'rm -rf "$tmp_dir"' EXIT
printf '%s' "$ledger_json" >"$tmp_dir/ledger.json"; printf '%s' "$boundary_json" >"$tmp_dir/boundary.json"
ledger="$tmp_dir/ledger.json"; boundary="$tmp_dir/boundary.json"; errors=0
fail() { printf '%s\n' "$1"; errors=$((errors + 1)); }
mapfile -t split_ids < <(jq -r '.candidates[]? | select(.decision == "split") | .id' "$boundary" | sort)
mapfile -t retain_ids < <(jq -r '.candidates[]? | select(.decision == "retain") | .id' "$boundary" | sort)
mapfile -t release_ids < <(jq -r '.releasePlugins[]?.id' "$ledger" | sort -u)
mapfile -t migration_ids < <(jq -r '.migrations[]?.newPluginId' "$ledger" | sort -u)
required_release=(dev-workflow growth adr writing "${split_ids[@]}")
[ "$(jq '.users | length' "$ledger")" -gt 0 ] || fail "利用者名簿が0件"
[ "$(jq '.releasePlugins | length' "$ledger")" -gt 0 ] || fail "release pluginが0件"
[ "$(jq -r '.approvals.J1 // empty' "$ledger")" = approved ] || fail "J1承認がありません"
for id in "${split_ids[@]}"; do
  jq -e --arg id "$id" '.candidates[] | select(.id == $id and .decision == "split" and .approval.status == "approved")' "$boundary" >/dev/null || fail "split pluginの承認がありません: $id"
done
for id in "${retain_ids[@]}"; do
  if printf '%s\n' "${migration_ids[@]} ${release_ids[*]}" | tr ' ' '\n' | grep -Fxq "$id"; then fail "retain候補をrelease/migrationへ追加しています: $id"; fi
done
check_row() {
  local old="$1" new="$2" skills="$3"
  jq -e --arg old "$old" --arg new "$new" --argjson skills "$skills" '.migrations[] | select(.oldPluginId == $old and .newPluginId == $new and .movedSkills == $skills and .oldEntryAction == "retain" and (.installCommand | strings | length > 0) and (.rollback | strings | length > 0))' "$ledger" >/dev/null || fail "J1対応表が不正: ${old}->${new}"
}
check_row dev-workflow dev-workflow '["create-issue","refine-issue","plan-issue","implementation"]'
for id in "${split_ids[@]}"; do check_row dev-workflow "$id" "$(jq -c --arg id "$id" '.candidates[] | select(.id == $id) | .skills' "$boundary")"; done
if jq -e '.migrations[]? | select(.oldPluginId == "dev-workflow" and .oldEntryAction == "delete")' "$ledger" >/dev/null; then fail "protected old plugin ID: dev-workflow"; fi
while IFS= read -r row; do
  [ -n "$row" ] || continue
  new=$(jq -r '.newPluginId' <<<"$row")
  case " dev-workflow growth adr writing ${split_ids[*]} " in *" $new "*) ;; *) fail "未知のmigration plugin ID: $new" ;; esac
done < <(jq -c '.migrations[]?' "$ledger")
while IFS= read -r row; do
  [ -n "$row" ] || continue
  action=$(jq -r '.oldEntryAction' <<<"$row")
  [ "$action" = delete ] || continue
  old=$(jq -r '.oldPluginId' <<<"$row")
  jq -e --arg old "$old" '.releasePlugins[] | select(.id == $old)' "$ledger" >/dev/null || fail "削除対象の旧plugin IDがrelease集合にありません: $old"
  jq -e '.installCommand | strings | length > 0' <<<"$row" >/dev/null || fail "削除行にinstallCommandがありません: $old"
  jq -e '.rollback | strings | length > 0' <<<"$row" >/dev/null || fail "削除行にrollbackがありません: $old"
done < <(jq -c '.migrations[]?' "$ledger")
for id in "${required_release[@]}"; do jq -e --arg id "$id" '.releasePlugins[] | select(.id == $id and (.version | strings | length > 0))' "$ledger" >/dev/null || fail "release集合に必要なpluginがありません: $id"; done
for id in "${release_ids[@]}"; do [ "$(jq --arg id "$id" '[.releasePlugins[] | select(.id == $id)] | length' "$ledger")" -eq 1 ] || fail "release plugin IDが一意ではありません: $id"; done
duplicates=$(jq -r '.releasePlugins[]?.skills[]?' "$ledger" | sort | uniq -d); [ -z "$duplicates" ] || fail "同名skillが重複配布されています: $duplicates"
pending_users=0
while IFS= read -r user; do
  [ -n "$user" ] || continue
  name=$(jq -r '.name' <<<"$user")
  [ "$(jq -r '.status' <<<"$user")" = confirmed ] || { echo "未確認利用者: $name"; pending_users=1; }
  for host in claude codex; do
    [ "$(jq -r --arg host "$host" '.[$host].status' <<<"$user")" = confirmed ] || { echo "未確認利用者: $name ($host)"; pending_users=1; }
    [ "$(jq -r --arg host "$host" '.[$host].version // empty' <<<"$user")" != "" ] || { echo "証拠versionがありません: $name ($host)"; pending_users=1; }
    [ "$(jq -r --arg host "$host" '.[$host].evidence // empty' <<<"$user")" != "" ] || { echo "検証証拠がありません: $name ($host)"; pending_users=1; }
  done
done < <(jq -c '.users[]?' "$ledger")
for id in "${release_ids[@]}"; do
  jq -e --arg id "$id" '.releaseNotes[]? | select(.pluginId == $id) | (.reason | strings | length > 0) and (.oldVersion | strings | length > 0) and (.newVersion | strings | length > 0) and (.compatibility | strings | length > 0) and (.breakingChanges | strings | length > 0) and (.rollback | strings | length > 0) and (.evidence | strings | length > 0)' "$ledger" >/dev/null || fail "release note必須字段がありません: $id"
done
j2=$(jq -r '.approvals.J2 // "pending"' "$ledger"); all_confirmed=1
while IFS= read -r status; do [ "$status" = confirmed ] || all_confirmed=0; done < <(jq -r '.users[]?.status' "$ledger")
can_delete=0; [ "$j2" = approved ] && [ "$all_confirmed" -eq 1 ] && [ "$pending_users" -eq 0 ] && [ "$errors" -eq 0 ] && can_delete=1
if [ "$mode" = validate ]; then
  [ "$errors" -eq 0 ] && [ "$pending_users" -eq 0 ] || exit 1
  [ "$can_delete" -eq 1 ] && echo "migration validation passed; deletion gate open" || echo "J2未承認または利用者未確認のため旧entry削除は不可"
  exit 0
fi
[ "$mode" = emit-actions ] || usage
actions_file="${4:-}"; [ -n "$actions_file" ] || usage
[ "$errors" -eq 0 ] && [ "$pending_users" -eq 0 ] || exit 1
delete_json='[]'; [ "$can_delete" -eq 1 ] && delete_json=$(jq -c '[.migrations[] | select(.oldEntryAction == "delete") | .oldPluginId] | unique' "$ledger")
mapfile -t add_ids < <(printf '%s\n' "${split_ids[@]}" | sed '/^$/d' | sort)
mapfile -t runner_ids < <(jq -r --argjson deleted "$delete_json" '.releasePlugins[]?.id as $id | select(($deleted | index($id)) == null) | $id' "$ledger" | sort -u)
jq -n --argjson add "$(printf '%s\n' "${add_ids[@]}" | sed '/^$/d' | jq -R . | jq -s .)" --argjson delete "$delete_json" --argjson retain "$(jq -c '[.migrations[] | select(.oldEntryAction == "retain") | .oldPluginId] | unique' "$ledger")" --argjson runner "$(printf '%s\n' "${runner_ids[@]}" | sed '/^$/d' | jq -R . | jq -s .)" '{addPluginIds:$add,deletePluginIds:$delete,retainPluginIds:$retain,runnerPluginIds:$runner}' >"$actions_file"
printf 'actions written: %s\n' "$actions_file"
