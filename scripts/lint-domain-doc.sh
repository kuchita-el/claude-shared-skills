#!/usr/bin/env bash
# DDDドキュメントリント（構造検証）
# - 禁止記号の検出
# - 廃止記法検出: `〜失敗理由 =` 独立型定義（コマンド内 `失敗時:` 配下に箇条書き化）
#
# 命名規約（イベント=過去形、コマンド=動詞辞書形 等）は形態素解析を要する
# 言語学的判定であり、機械的判定では原理的に誤検出・誤許容が生じるため
# 機械検証対象外とする。命名規約自体は
# `plugins/dev-workflow/skills/domain-modeling/references/domain-model-notation.md` に維持し、
# 人が守る規約として運用する（機械化再導入は #157 フェーズ2以降で検討）。
#
# 使い方:
#   bash scripts/lint-domain-doc.sh             # 固定3ファイルを検査
#   bash scripts/lint-domain-doc.sh path/...    # 指定ファイルのみ検査
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: 入力ファイル不存在
set -euo pipefail

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

# 廃止記法: 失敗理由独立型定義（コマンドセクション配下のコードブロック内）
# 例: `作成失敗理由 =`
check_failure_reason_type() {
    local file="$1"
    local line_num="$2"
    local line="$3"

    # 行頭非空白で `〜失敗理由` の後に空白を許容して `=` が来るパターン
    if [[ "$line" =~ ^[^[:space:]].*失敗理由[[:space:]]*= ]]; then
        printf '%s:%d: 廃止記法: 失敗理由の独立型定義は廃止（コマンドの「失敗時:」配下に箇条書きで記述）\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
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
                # H3 見出し: コマンドセクション追跡（廃止記法検査の位置情報用）
                if [[ "$line" =~ ^###[[:space:]]コマンド[[:space:]]*$ ]]; then
                    current_section="コマンド"
                elif [[ "$line" =~ ^###[[:space:]] ]]; then
                    current_section=""
                fi
            fi
        fi

        # 禁止記号検出（Mermaidブロック内は除外）
        if [ "$in_mermaid" -eq 0 ]; then
            check_prohibited "$file" "$line_num" "$line"
        fi

        # コマンドセクション配下のコードブロック内: 廃止記法検査
        if [ "$current_aggregate" -eq 1 ] && [ "$current_section" = "コマンド" ] && [ "$in_target_lang_block" -eq 1 ]; then
            check_failure_reason_type "$file" "$line_num" "$line"
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
