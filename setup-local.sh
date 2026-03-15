#!/usr/bin/env bash
# このリポジトリで開発中のスキルをローカルで使えるようにするセットアップスクリプト
set -euo pipefail
cd "$(dirname "$0")"

# --dry-run オプションの解析
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
  esac
done

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would create directory: .claude/skills"
else
  mkdir -p .claude/skills
fi

# 壊れたシンボリックリンクを削除
for link in .claude/skills/*; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "[DRY RUN] Would remove broken link: $link"
    else
      rm "$link"
    fi
  fi
done

# skills/ 内の各ディレクトリをリンク
for dir in skills/*/; do
  name=$(basename "$dir")
  target=".claude/skills/$name"
  if [ "$DRY_RUN" = true ]; then
    if [ ! -e "$target" ]; then
      echo "[DRY RUN] Would create link: $target -> ../../skills/$name"
    else
      echo "[DRY RUN] Already exists, skip: $target"
    fi
  else
    if [ ! -e "$target" ]; then
      ln -s "../../skills/$name" "$target"
    fi
  fi
done

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] No changes were made."
else
  echo "Done. Linked skills:"
  ls -la .claude/skills/
fi
