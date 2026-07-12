#!/usr/bin/env bash
# ADR drift-lint（レイヤ1: front-matter スキーマ検証／レイヤ2: index 同期検証）
#
# ADR_DIR 配下の ADR-*.md を走査し、front-matter を持つ ADR
# （先頭行が `---`）のみを対象に以下を検証する。front-matter を
# 持たない旧 `## Status` 形式は検査対象外としてスキップする（違反に数えない）。
#
# front-matter の抽出は yq/jq 等のパーサを使わず行走査で行う
# （scripts/gen-adr-index.sh の抽出方式に整合）。値は前後空白を
# トリムして判定する（末尾空白等で完全一致が静かに崩れるのを防ぐ）。
# キー省略と「キーあり値空」は同じ「空」として扱う。
#
# レイヤ1違反種別:
#   1. status 欠落（空）
#   2. status=承認済み かつ validity 欠落（空）
#   3. validity=上書き済み かつ superseded-by 欠落（空）
#
# 合法（違反にしない）:
#   - status=提案中 かつ validity 空
#   - status=却下 かつ validity 空
#   - validity=廃止済み かつ superseded-by 無し
#
# レイヤ2（index 同期）: scripts/gen-adr-index.sh を ADR_DIR に対して実行し、
# その出力を ADR_DIR/index.md と比較する。差分あり、または index.md が
# 不在の場合は同期違反とする。
#
# 全違反を列挙してから最後に非0 exitする（早期returnで打ち切らない）。
#
# 使い方:
#   bash scripts/lint-adr.sh [ADR_DIR]   # 既定 ADR_DIR は docs/adr/
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: ADR_DIR が存在しない
set -euo pipefail

ADR_DIR="${1:-docs/adr}"
ADR_DIR="${ADR_DIR%/}"

if [ ! -d "$ADR_DIR" ]; then
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    exit 2
fi

# 前後の空白（スペース・タブ）をトリムする
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# front-matter を持つか判定し、持つ場合は status/validity/superseded-by を
# グローバル変数 FM_STATUS/FM_VALIDITY/FM_SUPERSEDED_BY へトリム済みの値で
# 格納する（キー省略・値空はいずれも空文字）。
# 戻り値: front-matter を持てば 0、持たなければ 1
extract_frontmatter() {
    local file="$1"
    local line_num=0
    local in_fm=0
    local line key value

    FM_STATUS=""
    FM_VALIDITY=""
    FM_SUPERSEDED_BY=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_fm=1
                continue
            else
                return 1
            fi
        fi
        if [ "$in_fm" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                return 0
            fi
            if [[ "$line" =~ ^([a-zA-Z_-]+):[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="$(trim "${BASH_REMATCH[2]}")"
                case "$key" in
                    status) FM_STATUS="$value" ;;
                    validity) FM_VALIDITY="$value" ;;
                    superseded-by) FM_SUPERSEDED_BY="$value" ;;
                esac
            fi
        fi
    done <"$file"

    # front-matter が閉じずにファイル末尾へ達した場合も front-matter ありとして扱う
    [ "$in_fm" -eq 1 ]
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

violations=0

for file in "${sorted[@]}"; do
    if ! extract_frontmatter "$file"; then
        # front-matter を持たない旧形式はレイヤ1検査対象外（スキップ）
        continue
    fi

    if [ -z "$FM_STATUS" ]; then
        printf '%s: status が空です（front-matter に status キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    fi

    if [ "$FM_STATUS" = "承認済み" ] && [ -z "$FM_VALIDITY" ]; then
        printf '%s: status=承認済み だが validity が空です（validity キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    fi

    if [ "$FM_VALIDITY" = "上書き済み" ] && [ -z "$FM_SUPERSEDED_BY" ]; then
        printf '%s: validity=上書き済み だが superseded-by が空です（superseded-by キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    fi
done

# レイヤ2: index 同期検証
# 生成器の呼び出しはスクリプト自身の位置からの相対パスで解決する（cwd 依存回避）
GEN_INDEX="$(dirname "$0")/gen-adr-index.sh"
INDEX_FILE="$ADR_DIR/index.md"

if [ ! -f "$INDEX_FILE" ]; then
    printf '%s: index 同期違反（index.md が存在しません）\n' "$INDEX_FILE"
    violations=$((violations + 1))
else
    generated="$(bash "$GEN_INDEX" "$ADR_DIR")"
    current="$(cat "$INDEX_FILE")"
    if [ "$generated" != "$current" ]; then
        printf '%s: index 同期違反（gen-adr-index.sh の出力と一致しません。再生成してください）\n' "$INDEX_FILE"
        violations=$((violations + 1))
    fi
fi

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
