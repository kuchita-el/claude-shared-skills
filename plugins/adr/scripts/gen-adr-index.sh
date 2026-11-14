#!/usr/bin/env bash
# 有効 ADR index 生成器
#
# ADR_DIR 配下の ADR-*.md を走査し、front-matter の `validity: 有効` を持つ
# ADR のみをファイル名昇順で列挙した index を stdout へ出力する。
# front-matter は yq/jq 等のパーサを使わず行走査で抽出する
# （先頭行が `---` なら front-matter あり、次の `---` までを key: value として解釈。
#   先頭行が `---` でなければ旧 `## Status` 形式とみなし validity 無しとして扱う）。
#
# 生成入力を本文見出しの正規表現抽出ではなく front-matter の key-value 解析としたのは、
# 後者のほうが堅牢なためである（見出し抽出による生成は却下した）。
# index をファイル全体として生成物（build artifact）に倒し人手編集しない扱いとするのは、
# front-matter を唯一の権威としたうえで一覧をその導出ビューへ閉じ込めることで、
# 「本文を読めば確実」（確実性）と「一覧で探せる」（検索性）を drift させずに両立させるためである。
#
# 言語に依存する語（有効を表す validity の値・index の題名・冒頭の注記）は、設定から読む。
# 設定の解決と誤りの扱いは同梱の adr-config.sh が持ち、キーと既定値は adr-config.default が
# 持つ。本ファイルのコメントに現れる値（`有効` 等）は、既定値での綴りである。設定の解決の
# 起点は ADR_DIR であり、lint-adr.sh のレイヤ2 が同じ ADR_DIR で本スクリプトを起動するため、
# 両者は同じ設定を読む。
#
# 使い方:
#   bash gen-adr-index.sh [ADR_DIR]   # 既定 ADR_DIR は docs/adr/
#
# exit code:
#   0: 正常終了（有効 ADR が0件でも0）
#   2: ADR_DIR が存在しない、または設定に誤りがある
set -euo pipefail

ADR_DIR="${1:-docs/adr}"
ADR_DIR="${ADR_DIR%/}"

if [ ! -d "$ADR_DIR" ]; then
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    exit 2
fi

# 設定の読み込み部。ADR_DIR を起点に設定を解決する（誤りの原因は adr_config_load が出す）。
# shellcheck source=adr-config.sh
source "$(dirname "${BASH_SOURCE[0]}")/adr-config.sh"
adr_config_load "$ADR_DIR" || exit 2

# 前後の空白（スペース・タブ）をトリムする（lint-adr.sh の trim と同一実装）
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# front-matter から validity の値を取得（front-matter 無し／キー無し／値空はすべて空文字）
# 値は前後空白をトリムして返す（lint-adr.sh の抽出・判定と一致させる）
get_validity() {
    local file="$1"
    local line_num=0
    local in_fm=0
    local value=""
    local line

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_fm=1
                continue
            else
                break
            fi
        fi
        if [ "$in_fm" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                break
            fi
            if [[ "$line" =~ ^validity:[[:space:]]*(.*)$ ]]; then
                value="$(trim "${BASH_REMATCH[1]}")"
            fi
        fi
    done <"$file"

    printf '%s' "$value"
}

# 本文 H1 見出し `# <stem>: <タイトル>` からタイトル部分（最初の ": " 以降）を取得
get_title() {
    local file="$1"
    local line
    local rest

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#[[:space:]] ]]; then
            rest="${line#\# }"
            if [[ "$rest" == *": "* ]]; then
                printf '%s' "${rest#*: }"
                return
            fi
        fi
    done <"$file"

    printf '%s' ""
}

# ファイル名昇順で走査対象を収集
files=()
shopt -s nullglob
for f in "$ADR_DIR"/ADR-*.md; do
    files+=("$f")
done
shopt -u nullglob

sorted=()
if [ "${#files[@]}" -gt 0 ]; then
    while IFS= read -r f; do
        sorted+=("$f")
    done < <(printf '%s\n' "${files[@]}" | LC_ALL=C sort)
fi

printf '<!-- %s -->\n' "$ADR_INDEX_NOTICE"
printf '# %s\n' "$ADR_INDEX_TITLE"
echo ''

for file in "${sorted[@]}"; do
    validity="$(get_validity "$file")"
    if [ "$validity" = "$ADR_VALIDITY_ACTIVE" ]; then
        stem="$(basename "$file" .md)"
        title="$(get_title "$file")"
        printf -- '- [%s](./%s.md): %s\n' "$stem" "$stem" "$title"
    fi
done
