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

# 1ファイルを行単位で走査して禁止記号を検出
lint_file() {
    local file="$1"
    local in_mermaid=0
    local line_num=0
    local line label

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # コードブロック開閉判定（行頭3バックティック）
        if [[ "${line:0:3}" == '```' ]]; then
            if [ "$in_mermaid" -eq 1 ]; then
                in_mermaid=0
            else
                label="${line:3}"
                label="${label%%[[:space:]]*}"
                if [ "$label" = "mermaid" ]; then
                    in_mermaid=1
                fi
            fi
        fi

        # 禁止記号検出（Mermaidブロック内は除外）
        if [ "$in_mermaid" -eq 0 ]; then
            if [[ "${line:0:9}" == '```fsharp' ]]; then
                printf '%s:%d: 禁止記号: ```fsharp\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
            if [[ "$line" =~ ^type([[:space:]]|$) ]]; then
                printf '%s:%d: 禁止記号: ^type\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
            if [[ "$line" == *'->'* ]]; then
                printf '%s:%d: 禁止記号: ->\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
            if [[ "$line" == *'=>'* ]]; then
                printf '%s:%d: 禁止記号: =>\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
            if [[ "$line" == *'<>'* ]]; then
                printf '%s:%d: 禁止記号: <>\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
            if [[ "$line" == *'Result<'* ]]; then
                printf '%s:%d: 禁止記号: Result<\n' "$file" "$line_num"
                violations=$((violations + 1))
            fi
        fi
    done < "$file"
}

for file in "${files[@]}"; do
    lint_file "$file"
done

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
