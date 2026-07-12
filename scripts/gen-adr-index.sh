#!/usr/bin/env bash
# 有効 ADR index 生成器
#
# ADR_DIR 配下の ADR-*.md を走査し、front-matter の `validity: 有効` を持つ
# ADR のみをファイル名昇順で列挙した index を stdout へ出力する。
# front-matter は yq/jq 等のパーサを使わず行走査で抽出する
# （先頭行が `---` なら front-matter あり、次の `---` までを key: value として解釈。
#   先頭行が `---` でなければ旧 `## Status` 形式とみなし validity 無しとして扱う）。
#
# 使い方:
#   bash scripts/gen-adr-index.sh [ADR_DIR]   # 既定 ADR_DIR は docs/adr/
#
# exit code:
#   0: 正常終了（有効 ADR が0件でも0）
#   2: ADR_DIR が存在しない
set -euo pipefail

ADR_DIR="${1:-docs/adr}"
ADR_DIR="${ADR_DIR%/}"

if [ ! -d "$ADR_DIR" ]; then
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    exit 2
fi

# 前後の空白（スペース・タブ）をトリムする（scripts/lint-adr.sh の trim と同一実装）
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

echo '<!-- このファイルは scripts/gen-adr-index.sh による生成物。手動編集禁止。 -->'
echo '# 有効 ADR インデックス'
echo ''

for file in "${sorted[@]}"; do
    validity="$(get_validity "$file")"
    if [ "$validity" = "有効" ]; then
        stem="$(basename "$file" .md)"
        title="$(get_title "$file")"
        printf -- '- [%s](./%s.md): %s\n' "$stem" "$stem" "$title"
    fi
done
