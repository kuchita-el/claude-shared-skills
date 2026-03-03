#!/usr/bin/env bash
# このリポジトリで開発中のスキルをローカルで使えるようにするセットアップスクリプト
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p .claude/skills

# skills/ 内の各スキルディレクトリをリンク
for skill in skills/*/; do
  name=$(basename "$skill")
  target=".claude/skills/$name"
  if [ ! -e "$target" ]; then
    ln -s "../../skills/$name" "$target"
  fi
done

# defaults をリンク
if [ ! -e .claude/skills/defaults ]; then
  ln -s ../../defaults .claude/skills/defaults
fi

echo "Done. Linked skills:"
ls -la .claude/skills/
