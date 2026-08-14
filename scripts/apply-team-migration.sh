#!/usr/bin/env bash
set -euo pipefail

root="${1:?usage: apply-team-migration.sh <repo-root> <actions.json>}"
actions="${2:?usage: apply-team-migration.sh <repo-root> <actions.json>}"
jq empty "$actions" >/dev/null 2>&1 || { echo "actions JSON不正"; exit 1; }
for key in addPluginIds deletePluginIds retainPluginIds runnerPluginIds; do
  jq -e --arg key "$key" '.[$key] | type == "array"' "$actions" >/dev/null || { echo "actions field不正: $key"; exit 1; }
done

if jq -e '(.deletePluginIds + .addPluginIds | unique | length) != (.deletePluginIds + .addPluginIds | length)' "$actions" >/dev/null; then
  echo "add/delete plugin ID overlap"; exit 1
fi
if jq -e --argjson retain "$(jq '.retainPluginIds' "$actions")" --argjson runner "$(jq '.runnerPluginIds' "$actions")"   'any(.deletePluginIds[]; (. as $id | ($retain | index($id) != null) or ($runner | index($id) != null)))' "$actions" >/dev/null; then
  echo "deletePluginIds overlaps retainPluginIds or runnerPluginIds"; exit 1
fi
if jq -e '.deletePluginIds | index("dev-workflow") != null' "$actions" >/dev/null; then
  echo "protected old plugin ID: dev-workflow"; exit 1
fi

claude="$root/.claude-plugin/marketplace.json"
codex="$root/.agents/plugins/marketplace.json"
for file in "$claude" "$codex"; do
  jq empty "$file" >/dev/null 2>&1 || { echo "marketplace JSON不正: $file"; exit 1; }
done
for id in $(jq -r '.addPluginIds[]' "$actions"); do
  [ -d "$root/plugins/$id" ] || { echo "plugin directoryがありません: $id"; exit 1; }
done

tmp_claude=$(mktemp "${claude}.tmp.XXXXXX")
tmp_codex=$(mktemp "${codex}.tmp.XXXXXX")
cleanup() { rm -f "$tmp_claude" "$tmp_codex" "$tmp_claude.next" "$tmp_codex.next"; }
trap cleanup EXIT
cp "$claude" "$tmp_claude"
cp "$codex" "$tmp_codex"

for id in $(jq -r '.deletePluginIds[]' "$actions"); do
  jq --arg id "$id" '.plugins |= map(select(.name != $id))' "$tmp_claude" >"$tmp_claude.next"
  mv "$tmp_claude.next" "$tmp_claude"
  jq --arg id "$id" '.plugins |= map(select(.name != $id))' "$tmp_codex" >"$tmp_codex.next"
  mv "$tmp_codex.next" "$tmp_codex"
done
for id in $(jq -r '.addPluginIds[]' "$actions"); do
  if ! jq -e --arg id "$id" '.plugins[] | select(.name == $id)' "$tmp_claude" >/dev/null; then
    jq --arg id "$id" '.plugins += [(.plugins[0] | .name=$id | .source=("./plugins/" + $id))]' "$tmp_claude" >"$tmp_claude.next"
    mv "$tmp_claude.next" "$tmp_claude"
  fi
  if ! jq -e --arg id "$id" '.plugins[] | select(.name == $id)' "$tmp_codex" >/dev/null; then
    jq --arg id "$id" '.plugins += [(.plugins[0] | .name=$id | .source.path=("./plugins/" + $id))]' "$tmp_codex" >"$tmp_codex.next"
    mv "$tmp_codex.next" "$tmp_codex"
  fi
done
for file in "$tmp_claude" "$tmp_codex"; do
  jq -e '.plugins[] | select(.name == "dev-workflow")' "$file" >/dev/null || { echo "protected old plugin ID: dev-workflow"; exit 1; }
done

mv "$tmp_claude" "$claude"
mv "$tmp_codex" "$codex"
trap - EXIT
printf 'team migration actions applied\n'
