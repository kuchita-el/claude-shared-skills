#!/usr/bin/env bash
# このリポジトリのプラグインをCodexへ登録する
set -euo pipefail

cd "$(dirname "$0")"

marketplace_name="claude-shared-skills"

if ! codex plugin marketplace list | grep -Fq "$marketplace_name"; then
  codex plugin marketplace add .
fi

installed_plugins="$(codex plugin list --json)"

mapfile -t plugins < <(jq -r '.plugins[]?.name // empty' .agents/plugins/marketplace.json)
[ "${#plugins[@]}" -gt 0 ] || { echo "Codex marketplaceの対象pluginが0件" >&2; exit 1; }
for plugin in "${plugins[@]}"; do
  plugin_id="${plugin}@${marketplace_name}"
  if ! grep -Fq "\"pluginId\": \"${plugin_id}\"" <<<"$installed_plugins"; then
    codex plugin add "$plugin_id"
  fi
done

if ! grep -Fq '"pluginId": "superpowers@openai-curated"' <<<"$installed_plugins"; then
  codex plugin add superpowers@openai-curated
fi

exec codex "$@"
