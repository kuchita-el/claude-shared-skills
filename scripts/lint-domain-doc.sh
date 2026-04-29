#!/usr/bin/env bash
# DDDドキュメントリント
# - 禁止記号の検出
# - 命名規約の検査（日本語名のみ、集約セクション配下の指定3見出し配下のコードブロック内）
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

# 違反カウンタ（lint_file 関数内から更新する）
violations=0

# 禁止記号検出
check_prohibited() {
    local file="$1"
    local line_num="$2"
    local line="$3"

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
}

# 命名規約検査
check_naming() {
    local file="$1"
    local line_num="$2"
    local line="$3"
    local section="$4"
    local name

    # 行頭定義行: インデントなしで `=` or `:` を含む
    if ! [[ "$line" =~ ^[^[:space:]][^=:]*[=:] ]]; then
        return
    fi

    # 名前部分: 最初の `=`/`:` 手前まで
    name="${line%%[=:]*}"
    # 前後空白除去
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"

    if [ -z "$name" ]; then
        return
    fi

    # 日本語含有判定（ひらがな・カタカナ・漢字）
    if ! grep -qP '[\x{3040}-\x{30ff}\x{4e00}-\x{9fff}]' <<<"$name"; then
        return  # 英語名は対象外
    fi

    case "$section" in
        コマンド)
            if [[ "$name" != *する ]]; then
                printf '%s:%d: 命名規約: %s: コマンド名は動詞句でない\n' "$file" "$line_num" "$name"
                violations=$((violations + 1))
            fi
            ;;
        発火するイベント)
            if [[ "$name" != *した && "$name" != *された ]]; then
                printf '%s:%d: 命名規約: %s: イベント名は過去形でない\n' "$file" "$line_num" "$name"
                violations=$((violations + 1))
            fi
            ;;
        状態遷移)
            if [[ "$name" != *する ]]; then
                printf '%s:%d: 命名規約: %s: 状態遷移名は動詞句でない\n' "$file" "$line_num" "$name"
                violations=$((violations + 1))
            fi
            ;;
    esac
}

# 1ファイルを行単位で 1 パス走査
lint_file() {
    local file="$1"
    local in_mermaid=0
    local in_target_lang_block=0
    local current_aggregate=0
    local current_section=""
    local line_num=0
    local line label

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # コードブロック開閉判定（行頭3バックティック）
        if [[ "${line:0:3}" == '```' ]]; then
            if [ "$in_mermaid" -eq 1 ]; then
                in_mermaid=0
            elif [ "$in_target_lang_block" -eq 1 ]; then
                in_target_lang_block=0
            else
                # 開始: ラベル抽出
                label="${line:3}"
                label="${label%%[[:space:]]*}"
                if [ "$label" = "mermaid" ]; then
                    in_mermaid=1
                elif [ "$label" = "fsharp" ] || [ -z "$label" ]; then
                    in_target_lang_block=1
                fi
                # 他のラベルは何もしない
            fi
        else
            # コードブロック外でのみ見出し処理
            if [ "$in_mermaid" -eq 0 ] && [ "$in_target_lang_block" -eq 0 ]; then
                # H2 見出し（H3 とは区別）
                if [[ "$line" =~ ^##[[:space:]] ]] && ! [[ "$line" =~ ^### ]]; then
                    if [[ "$line" =~ ^##[[:space:]].+集約[[:space:]]*$ ]]; then
                        current_aggregate=1
                    else
                        current_aggregate=0
                    fi
                    current_section=""
                fi
                # H3 見出し
                if [[ "$line" =~ ^###[[:space:]](コマンド|発火するイベント|状態遷移)[[:space:]]*$ ]]; then
                    current_section="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^###[[:space:]] ]]; then
                    current_section=""
                fi
            fi
        fi

        # 禁止記号検出（Mermaidブロック内は除外）
        if [ "$in_mermaid" -eq 0 ]; then
            check_prohibited "$file" "$line_num" "$line"
        fi

        # 命名規約検査（naming_target_block）
        if [ "$current_aggregate" -eq 1 ] && [ -n "$current_section" ] && [ "$in_target_lang_block" -eq 1 ]; then
            check_naming "$file" "$line_num" "$line" "$current_section"
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
