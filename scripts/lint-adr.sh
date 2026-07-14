#!/usr/bin/env bash
# ADR drift-lint（レイヤ1: front-matter スキーマ検証／レイヤ2: index 同期検証／
# レイヤ3: 相互参照双方向性検証）
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
# レイヤ3（相互参照双方向性）: 「A.superseded-by=B ⟺ B 本文 `## 関連ADR` に
# `Supersedes: A`（フル slug 完全一致）」の真の双方向（⟺）を検証する。
#   - forward（front-matter起点）: front-matter に superseded-by: B を持つ
#     ADR A について、B（ADR_DIR/B.md）の本文に `Supersedes: A` があるかを
#     照合する。B が存在しない、または本文に逆参照が無ければ違反。
#   - reverse（本文起点）: 本文 `## 関連ADR` 節で `Supersedes: T` を宣言する
#     ADR C について、T（ADR_DIR/T.md）の front-matter superseded-by が C を
#     指しているかを照合する。T が存在しない、または front-matter が C を
#     指していなければ違反（本文で Supersedes 宣言したが front-matter 側の
#     更新を忘れ、T が validity: 有効 のまま index に残るドリフトを検出する）。
# forward・reverse は互いに独立した検査（片方が満たされればもう片方は
# 発火しない設計）であり、双方が揃うエッジは違反にしない（二重計上しない）。
# `Amends:`/`Amended by:` のみを持つエッジは凍結扱いで両方向とも検査対象外
# （本文走査は `Supersedes:` のみを対象にする）。
# `Supersedes:` 行は行頭空白（入れ子/インデントされたバレット）を許容して
# 抽出する（forward の照合・reverse の抽出のいずれも同一の緩和を適用）。
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

# カンマ区切りの superseded-by 値を各要素トリム・空要素スキップで
# グローバル配列 SPLIT_RESULT へ分割する（リスト値 1→N 分割 ADR 対応）。
# 単一値はカンマを含まないため要素数1の配列となり、従来の完全一致挙動を保つ。
# 末尾・連続カンマ由来の空要素はトリム後スキップする（堅牢性目的の防御）。
split_csv() {
    local input="$1" elem
    local raw
    SPLIT_RESULT=()
    IFS=',' read -ra raw <<<"$input"
    for elem in ${raw[@]+"${raw[@]}"}; do
        elem="$(trim "$elem")"
        [ -n "$elem" ] && SPLIT_RESULT+=("$elem")
    done
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

# ファイル file の本文中の `## 関連ADR` 節（次の `## ` 見出しまたは
# ファイル末尾まで）に `- Supersedes: <target_stem>`（フル slug 完全一致。
# 行頭空白＝入れ子/インデントされたバレットも許容）の行が存在するかを判定する。
# 戻り値: 存在すれば 0、しなければ 1
body_has_supersedes() {
    local file="$1"
    local target_stem="$2"
    local line in_section=0 candidate

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+関連ADR ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*Supersedes:[[:space:]]*([A-Za-z0-9-]+) ]]; then
            candidate="${BASH_REMATCH[1]}"
            if [ "$candidate" = "$target_stem" ]; then
                return 0
            fi
        fi
    done <"$file"

    return 1
}

# ファイル file の本文中の `## 関連ADR` 節（次の `## ` 見出しまたは
# ファイル末尾まで）にある `Supersedes: <target_stem>`（フル slug 完全一致、
# 行頭空白＝入れ子/インデントされたバレットを許容）をすべて抽出し、
# グローバル配列 BODY_SUPERSEDES_TARGETS へ格納する（0件なら空配列）。
# レイヤ3 reverse（本文起点）の照合対象を集めるために使う。
extract_body_supersedes() {
    local file="$1"
    local line in_section=0

    BODY_SUPERSEDES_TARGETS=()

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+関連ADR ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*Supersedes:[[:space:]]*([A-Za-z0-9-]+) ]]; then
            BODY_SUPERSEDES_TARGETS+=("${BASH_REMATCH[1]}")
        fi
    done <"$file"
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

# レイヤ3 forward で照合する superseded-by ペア（front-matter を持つ ADR のみ対象）
xref_sources=()
xref_targets=()

# レイヤ3 reverse の照合用: stem -> front-matter superseded-by 値
# （front-matter を持たない、または superseded-by が空の場合はキー未設定のまま。
#   参照時は "${FM_SB_BY_STEM[$stem]:-}" で空扱いにする）
declare -A FM_SB_BY_STEM=()

for file in "${sorted[@]}"; do
    if ! extract_frontmatter "$file"; then
        # front-matter を持たない旧形式はレイヤ1検査対象外（スキップ）
        continue
    fi

    FM_SB_BY_STEM["$(basename "$file" .md)"]="$FM_SUPERSEDED_BY"

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

    if [ -n "$FM_SUPERSEDED_BY" ]; then
        xref_sources+=("$file")
        xref_targets+=("$FM_SUPERSEDED_BY")
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

# レイヤ3 forward: front-matter superseded-by 起点で本文 Supersedes 逆参照を照合
for i in "${!xref_sources[@]}"; do
    a_file="${xref_sources[$i]}"
    a_stem="$(basename "$a_file" .md)"

    # superseded-by をカンマ分割し、各後継 stem を独立に照合する（リスト値 1→N 対応）
    split_csv "${xref_targets[$i]}"
    for b_stem in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        b_file="$ADR_DIR/$b_stem.md"

        if [ ! -f "$b_file" ]; then
            printf '%s: 相互参照違反（superseded-by=%s だが参照先 %s が見つかりません）\n' "$a_file" "$b_stem" "$b_file"
            violations=$((violations + 1))
            continue
        fi

        if ! body_has_supersedes "$b_file" "$a_stem"; then
            printf '%s: 相互参照違反（%s の本文 "## 関連ADR" に "Supersedes: %s" が見つかりません）\n' "$a_file" "$b_file" "$a_stem"
            violations=$((violations + 1))
        fi
    done
done

# レイヤ3 reverse: 本文 Supersedes 宣言起点で front-matter superseded-by を照合
# （C の本文が Supersedes: T を宣言するのに、T の front-matter superseded-by
#   が C を指していない＝front-matter 更新忘れを検出する。forward で既に
#   一致確認済みのエッジは reverse 側でも自然に一致するため、ここでは
#   forward 側で捕捉できない「本文はあるが front-matter が追随していない」
#   ケースのみが新たに violation として計上される＝二重計上にならない）
for c_file in "${sorted[@]}"; do
    extract_body_supersedes "$c_file"
    c_stem="$(basename "$c_file" .md)"

    for t_stem in "${BODY_SUPERSEDES_TARGETS[@]}"; do
        t_file="$ADR_DIR/$t_stem.md"

        if [ ! -f "$t_file" ]; then
            printf '%s: 相互参照違反（逆方向: 本文 "## 関連ADR" の "Supersedes: %s" 宣言の参照先 %s が見つかりません）\n' "$c_file" "$t_stem" "$t_file"
            violations=$((violations + 1))
            continue
        fi

        # T の superseded-by をリスト分割した集合に c_stem が含まれるかで判定する
        # （完全一致から集合メンバシップへ。単一値は要素数1集合となり従来と等価＝後方互換）
        split_csv "${FM_SB_BY_STEM[$t_stem]:-}"
        member=0
        for s in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
            if [ "$s" = "$c_stem" ]; then
                member=1
                break
            fi
        done
        if [ "$member" -eq 0 ]; then
            printf '%s: 相互参照違反（逆方向: %s の本文 "## 関連ADR" が "Supersedes: %s" を宣言していますが、%s の front-matter superseded-by がそれを指していません）\n' "$t_file" "$c_file" "$t_stem" "$t_file"
            violations=$((violations + 1))
        fi
    done
done

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
