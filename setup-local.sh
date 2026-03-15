#!/usr/bin/env bash
# このリポジトリで開発中のスキルをローカルで使えるようにするセットアップスクリプト
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p .claude/skills

count_created=0
count_skipped=0
count_removed=0

# 壊れたシンボリックリンクを削除
for link in .claude/skills/*; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    rm "$link"
    count_removed=$((count_removed + 1))
  fi
done

# skills/ 内の各ディレクトリをリンク
for dir in skills/*/; do
  name=$(basename "$dir")
  target=".claude/skills/$name"
  if [ ! -e "$target" ]; then
    ln -s "../../skills/$name" "$target"
    count_created=$((count_created + 1))
  else
    count_skipped=$((count_skipped + 1))
  fi
done

echo "=== Setup Complete ==="
echo "  新規リンク作成: ${count_created}"
echo "  既存スキップ:   ${count_skipped}"
echo "  壊れたリンク削除: ${count_removed}"
