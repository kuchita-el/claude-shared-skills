#!/usr/bin/env bash
# このリポジトリのプラグインをCodexへ登録する
set -euo pipefail

cd "$(dirname "$0")"

marketplace_name="claude-shared-skills"

if [[ $# -gt 1 || (${1:-} != "" && ${1:-} != "--with-superpowers") ]]; then
  echo "usage: $0 [--with-superpowers]" >&2
  exit 2
fi

if ! codex plugin marketplace list | grep -Fq "$marketplace_name"; then
  codex plugin marketplace add .
fi

installed_plugins="$(codex plugin list --json)"

for plugin in dev-workflow growth adr writing; do
  plugin_id="${plugin}@${marketplace_name}"
  if ! grep -Fq "\"pluginId\": \"${plugin_id}\"" <<<"$installed_plugins"; then
    codex plugin add "$plugin_id"
  fi
done

if [[ "${1:-}" == "--with-superpowers" ]]; then
  if ! grep -Fq '"pluginId": "superpowers@openai-curated"' <<<"$installed_plugins"; then
    codex plugin add superpowers@openai-curated
  fi
fi
