#!/usr/bin/env bash
# DDDドキュメントリント
# - 禁止記号の検出
# - 命名規約の検査（日本語名のみ）
#
# 使い方:
#   bash scripts/lint-domain-doc.sh             # 固定3ファイルを検査
#   bash scripts/lint-domain-doc.sh path/...    # 指定ファイルのみ検査
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: 入力ファイル不存在
#   3: GNU grep 不在
set -euo pipefail

# 環境前提検証: GNU grep（grep -P 対応）が必要
if ! grep -P -q . <<<"x" 2>/dev/null; then
    echo "エラー: GNU grep（grep -P 対応）が必要です。Linux を使うか、macOS では 'brew install grep' を実行してください。" >&2
    exit 3
fi

# 対象ファイルの決定
if [ "$#" -eq 0 ]; then
    files=(
        "docs/development/event-storming.md"
        "docs/development/domain-model.md"
        "docs/qa/event-storming.md"
    )
else
    files=("$@")
fi

# ファイル存在確認
for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
        echo "エラー: ファイルが見つかりません: $f" >&2
        exit 2
    fi
done

# 違反カウンタ
violations=0

# 各ファイルを処理（Task 2/3 で本実装）
for file in "${files[@]}"; do
    : "$file"
done

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
