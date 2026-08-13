#!/usr/bin/env bash
set -euo pipefail
root="${1:?usage: apply-team-migration.sh <repo-root> <actions.json>}"
actions="${2:?usage: apply-team-migration.sh <repo-root> <actions.json>}"
jq empty "$actions" >/dev/null 2>&1 || { echo "actions JSON不正"; exit 1; }
for key in addPluginIds deletePluginIds retainPluginIds runnerPluginIds; do
  jq -e --arg key "$key" '.[$key] | type == "array"' "$actions" >/dev/null || { echo "actions field不正: $key"; exit 1; }
done
if jq -e '.deletePluginIds | index("dev-workflow") != null' "$actions" >/dev/null; then echo "protected old plugin ID: dev-workflow"; exit 1; fi
claude="$root/.claude-plugin/marketplace.json"; codex="$root/.agents/plugins/marketplace.json"
for file in "$claude" "$codex"; do jq empty "$file" >/dev/null 2>&1 || { echo "marketplace JSON不正: $file"; exit 1; }; done
for id in $(jq -r '.deletePluginIds[]' "$actions"); do
  jq --arg id "$id" '.plugins |= map(select(.name != $id))' "$claude" >"$claude.tmp"; mv "$claude.tmp" "$claude"
  jq --arg id "$id" '.plugins |= map(select(.name != $id))' "$codex" >"$codex.tmp"; mv "$codex.tmp" "$codex"
done
for id in $(jq -r '.addPluginIds[]' "$actions"); do
  [ -d "$root/plugins/$id" ] || { echo "plugin directoryがありません: $id"; exit 1; }
  if ! jq -e --arg id "$id" '.plugins[] | select(.name == $id)' "$claude" >/dev/null; then
    jq --arg id "$id" '.plugins += [(.plugins[0] | .name=$id | .source=( "./plugins/" + $id))]' "$claude" >"$claude.tmp"; mv "$claude.tmp" "$claude"
  fi
  if ! jq -e --arg id "$id" '.plugins[] | select(.name == $id)' "$codex" >/dev/null; then
    jq --arg id "$id" '.plugins += [(.plugins[0] | .name=$id | .source.path=( "./plugins/" + $id))]' "$codex" >"$codex.tmp"; mv "$codex.tmp" "$codex"
  fi
done
for file in "$claude" "$codex"; do
  jq -e '.plugins[] | select(.name == "dev-workflow")' "$file" >/dev/null || { echo "protected old plugin ID: dev-workflow"; exit 1; }
done
printf 'team migration actions applied
'
