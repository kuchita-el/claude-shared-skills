#!/usr/bin/env bash
# このリポジトリで開発中のスキルをローカルで使えるようにするセットアップスクリプト
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p .claude/skills

# skills/ 内の各ディレクトリをリンク（スキル + defaults）
for dir in skills/*/; do
  name=$(basename "$dir")
  target=".claude/skills/$name"
  if [ ! -e "$target" ]; then
    ln -s "../../skills/$name" "$target"
  fi
done

echo "Done. Linked skills:"
ls -la .claude/skills/
