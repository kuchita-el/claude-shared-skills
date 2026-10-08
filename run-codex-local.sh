#!/usr/bin/env bash
# このリポジトリの作業ツリーをマーケットプレイスとして、開発用の Codex を起動する。
#
# 日常の Codex のホーム（CODEX_HOME、既定は ~/.codex）には触れない。開発用のホーム
# （CODEX_LOCAL_HOME、既定は ~/.codex-dev）を CODEX_HOME にして起動する。
# - マーケットプレイスの参照先は、起動ごとの上書き（-c）でこの作業ツリーへ向ける
# - Codex はプラグインの中身を参照先ではなくホームのキャッシュから読む。そのため起動のたびに
#   全プラグインを plugin add し、キャッシュを作業ツリーの今の内容で作り直す
# - ログインは、日常のホームの auth.json へのリンクで共有する
set -euo pipefail

cd "$(dirname "$0")"
repo_dir="$PWD"
marketplace_name="claude-shared-skills"
daily_home="${CODEX_HOME:-$HOME/.codex}"
dev_home="${CODEX_LOCAL_HOME:-$HOME/.codex-dev}"

mapfile -t plugins < <(jq -r '.plugins[]?.name // empty' .agents/plugins/marketplace.json)
[ "${#plugins[@]}" -gt 0 ] || { echo "Codex marketplaceの対象pluginが0件" >&2; exit 1; }

mkdir -p "$dev_home"
dev_home="$(cd "$dev_home" && pwd -P)"
if [ -d "$daily_home" ] && [ "$(cd "$daily_home" && pwd -P)" = "$dev_home" ]; then
  echo "開発用のホームが日常のホームと同じ: $dev_home（CODEX_LOCAL_HOME を見直す）" >&2
  exit 1
fi

if [ -f "$daily_home/auth.json" ] && [ ! -e "$dev_home/auth.json" ] && [ ! -L "$dev_home/auth.json" ]; then
  ln -s "$daily_home/auth.json" "$dev_home/auth.json"
fi

export CODEX_HOME="$dev_home"
overrides=(
  -c "marketplaces.${marketplace_name}.source_type=\"local\""
  -c "marketplaces.${marketplace_name}.source=\"${repo_dir}\""
)

for plugin in "${plugins[@]}"; do
  codex "${overrides[@]}" plugin add "${plugin}@${marketplace_name}" > /dev/null
done
if ! codex "${overrides[@]}" plugin add superpowers@openai-curated > /dev/null 2>&1; then
  echo "警告: superpowers@openai-curated を導入できなかった。Superpowers なしで起動する" >&2
fi

exec codex "${overrides[@]}" "$@"
