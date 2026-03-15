#!/usr/bin/env bash
# このリポジトリで開発中のスキルをローカルで使えるようにするセットアップスクリプト
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p .claude/skills

# カウンター初期化
created=0
skipped=0
removed=0

# 壊れたシンボリックリンクを削除
for link in .claude/skills/*; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    rm "$link"
    removed=$((removed + 1))
  fi
done

# skills/ 内の各ディレクトリをリンク
for dir in skills/*/; do
  name=$(basename "$dir")
  target=".claude/skills/$name"
  if [ ! -e "$target" ]; then
    ln -s "../../skills/$name" "$target"
    created=$((created + 1))
  else
    skipped=$((skipped + 1))
  fi
done

echo "Done. Linked skills:"
ls -la .claude/skills/
echo ""
echo "Summary: created=$created, skipped=$skipped (already exist), removed=$removed (broken)"
