#!/usr/bin/env bash
# .claude/skills/ のシンボリックリンクの整合性をチェックするスクリプト

cd /home/kuchita/Development/claude-shared-skills

count=0
broken=0

for link in .claude/skills/*; do
  if [ -L "$link" ]; then
    count=$((count + 1))
    target=$(readlink "$link")
    if [ ! -e "$link" ]; then
      echo "BROKEN: $link -> $target"
      broken=$((broken + 1))
    else
      echo "OK: $link -> $target"
    fi
  fi
done

echo ""
echo "チェック完了: $count リンク中 $broken 件が壊れています"

if [ $broken -gt 0 ]; then
  echo "壊れたリンクを修復するには ./setup-local.sh を実行してください"
fi
