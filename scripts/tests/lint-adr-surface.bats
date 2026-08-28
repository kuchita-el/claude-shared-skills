#!/usr/bin/env bats
# manage-adr スキル面に対する編集機構の面検査。
#
# 新スキーマの編集機構に関する旧記述の除去を検査する。
# 運用ルールの正本は docs/adr/README.md ではなく manage-adr スキル側にあるため、存在検査の
# 対象を移設先（edit-decision.md）へ張り替えてある。除去検査は、旧記述が再混入しうる面＝
# manage-adr のスキル面（正本の在処）に対して行う。host 固有の docs/adr/README.md は
# プラグイン非搭載のため、可搬な本テストの surface からは除外する。
# 除去検査の検査語は必ず見出しでアンカーする。裸の部分文字列にすると「節の復活」ではなく
# 「節を名指しすること」を禁じてしまい、廃止の経緯を説明する散文まで書けなくなるため。
#
# 【本ファイルが集約報告の中核である】
# 旧実装は存在検査・被覆検査のいずれも最初の1件で `return` し、欠落が複数あっても報告は
# 1件だけだった。さらに緑経路では総数を1つも加算せず、失敗時にのみ加算していたため、
# アサーション総数がその回の失敗状況で変動した。
# ここでは打ち切りを全廃し、欠落を全件バッファへ積んで1メッセージへ集約する。登録ケース数は
# 入力（ファイル数・欠落数）に依存せず常に一定であり、列挙結果でケースを動的生成しない。
# その結果、面①②は緑経路でも報告される独立ケースになる。両者は旧ランナーに対応する
# `[PASS]` ラベルを持たない新規ケースである（移行等価性の「増分の事前宣言」を参照）。

load 'helpers/common'

MANAGE_ADR_DIR="$PLUGIN_ROOT/skills/manage-adr"
EDIT_DECISION="$MANAGE_ADR_DIR/references/edit-decision.md"

PRECONDITION_PATHS=("$MANAGE_ADR_DIR")

# 除去検査の対象面を構成するファイルを明示列挙する。surface を glob（references/*.md）
# で組み立てると、ファイルが削除されても glob が静かに縮小するだけで検査が素通りし、
# 対象面が無言で狭まる。glob 結果に存在チェックを掛けても同じ理由で検知できないため、
# 期待リストを固定し、存在チェックと surface の構成元をこのリストに一致させる。
AC5_SURFACE_FILES=(
    "$MANAGE_ADR_DIR/SKILL.md"
    "$MANAGE_ADR_DIR/references/adr-demotion.md"
    "$MANAGE_ADR_DIR/references/adr-destination.md"
    "$MANAGE_ADR_DIR/references/adr-model.md"
    "$MANAGE_ADR_DIR/references/adr-reference-principle.md"
    "$MANAGE_ADR_DIR/references/adr-scoping.md"
    "$MANAGE_ADR_DIR/references/adr-splitting.md"
    "$MANAGE_ADR_DIR/references/cross-references.md"
    "$EDIT_DECISION"
    "$MANAGE_ADR_DIR/references/template.md"
    "$MANAGE_ADR_DIR/references/transitions.md"
)

setup_file() {
    common_setup_file
}

@test "前提: manage-adr スキルディレクトリが存在する" {
    assert_preconditions_met
}

@test "面①: 期待リストのファイルがすべて存在する" {
    collect_init

    local f rel
    for f in "${AC5_SURFACE_FILES[@]}"; do
        rel="${f#"$REPO_ROOT"/}"
        if [ -f "$f" ]; then
            collect_ok "AC5: surface file exists: $rel"
        else
            # 1件目で打ち切らない。欠落が複数あれば1回の実行で全件を報告する。
            collect_fail "AC5: surface file exists: $rel" "surface file not found: $f"
        fi
    done

    collect_finish
}

# 逆向きの縮小（参照ファイルが増えたのに期待リストへ未登録＝その面だけ検査から漏れる）
# も検知する。nullglob で空マッチ時にリテラルが残らないことを明示する。
@test "面②: 参照ファイルが期待リストに被覆されている" {
    collect_init

    # `shopt -p` はオプションが off のとき exit 1 を返すため、errexit 下では `|| true` が要る。
    local prev_nullglob
    prev_nullglob="$(shopt -p nullglob || true)"
    shopt -s nullglob
    local actual_refs=("$MANAGE_ADR_DIR"/references/*.md "$MANAGE_ADR_DIR"/references/*.json)
    eval "$prev_nullglob"

    local actual rel
    for actual in ${actual_refs[@]+"${actual_refs[@]}"}; do
        rel="${actual#"$REPO_ROOT"/}"
        case " ${AC5_SURFACE_FILES[*]} " in
            *" $actual "*)
                collect_ok "AC5: surface file list covers: $rel"
                ;;
            *)
                # ここも打ち切らない。未登録が複数あれば1回の実行で全件を報告する。
                collect_fail "AC5: surface file list covers: $rel" \
                    "surface file list does not cover: $actual"
                ;;
        esac
    done

    collect_finish
}

@test "面④: manage-adr スキル面からの旧節除去" {
    collect_init

    local surface
    surface=$(cat "${AC5_SURFACE_FILES[@]}" 2>/dev/null || true)

    collect_not_contains "$surface" "## モデル制約由来の設計判断インデックス" \
        "AC5: 旧モデル制約由来の設計判断インデックス節が manage-adr スキル面から除去されている"
    collect_not_contains "$surface" "### Amended（部分改訂）" \
        "AC5: 旧 Amended（部分改訂）手順節が manage-adr スキル面から除去されている"
    collect_not_contains "$surface" "## 保留した決定" \
        "AC5: 旧「保留した決定」節が manage-adr スキル面から除去されている"

    collect_finish
}

# ---- 節名参照の解決 ----
#
# 参照面は「正本のファイル名と節名を直接書いて指す」作法で組まれており、`SKILL.md` の
# フィードバックループは `adr-model.md`「検査項目と正本の対応」表を唯一の索引にしている。
# 節を改名・削除しても指す側は静かに壊れるだけで、lint も既存のテストも赤にならない。
# 節名参照の解決を検査に載せ、指し先の消滅を退行として捕まえる。
#
# 照合件数の下限を明示するのは、抽出が退行したときに少ない件数のまま緑になるのを防ぐため。
# 下限は名目値（1件）ではなく現在の実数を置く。名目値にすると、抽出が部分的に壊れて
# 数件しか拾えなくなっても緑のまま通り、下限が検査として働かない。

# 参照面に現存する節名参照の件数。参照を減らす変更でここが赤になるのは意図した摩擦であり、
# 減らすことが正しいと判断した場合に限り本定数を下げる。
AC5_SECTION_REF_MIN=31

# 参照面の見出しを "<basename><TAB><見出しテキスト>" の行として出す。
surface_heading_index() {
    local f base h
    for f in "${AC5_SURFACE_FILES[@]}"; do
        [ -f "$f" ] || continue
        base="${f##*/}"
        while IFS= read -r h; do
            printf '%s\t%s\n' "$base" "$h"
        done < <(sed -n 's/^#\{1,6\}[[:space:]]\{1,\}\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$f")
    done
}

# 参照面から `<path>.md`「<節名>」 形式の節名参照を取り出し、
# "<参照元basename><TAB><参照先basename><TAB><節名>" の行として出す。
# 多バイト文字を awk の文字クラスへ入れると mawk ではバイト単位に分解されて誤判定するため、
# 抽出は bash のリテラル部分文字列操作だけで行う。
surface_section_refs() {
    local f base line rest before path sec
    local delim='`「'
    for f in "${AC5_SURFACE_FILES[@]}"; do
        [ -f "$f" ] || continue
        base="${f##*/}"
        while IFS= read -r line; do
            rest="$line"
            while [ -n "$rest" ]; do
                case "$rest" in
                    *"$delim"*) : ;;
                    *) break ;;
                esac
                before="${rest%%"$delim"*}"
                rest="${rest#*"$delim"}"
                path="${before##*\`}"
                case "$rest" in
                    *"」"*) sec="${rest%%」*}" ;;
                    *) continue ;;
                esac
                case "$path" in
                    *.md) printf '%s\t%s\t%s\n' "$base" "${path##*/}" "$sec" ;;
                esac
            done
        done < "$f"
    done
}

@test "面⑤: 参照面の節名参照がすべて実在の見出しへ解決する" {
    collect_init

    local index refs
    index="$(surface_heading_index)"
    refs="$(surface_section_refs)"

    local total=0
    if [ -n "$refs" ]; then
        total="$(printf '%s\n' "$refs" | wc -l)"
    fi

    # 抽出が退行したまま緑になるのを防ぐ下限。
    if [ "$total" -ge "$AC5_SECTION_REF_MIN" ]; then
        collect_ok "AC5: 節名参照の照合件数が下限を満たす（$total 件 / 下限 $AC5_SECTION_REF_MIN 件）"
    else
        collect_fail "AC5: 節名参照の照合件数が下限を満たす" \
            "照合件数 $total 件が下限 $AC5_SECTION_REF_MIN 件を下回る（抽出の退行か参照の削減。後者なら本定数を下げる）"
    fi

    local src dst sec needle label
    while IFS=$'\t' read -r src dst sec; do
        [ -n "$dst" ] || continue
        label="AC5: 節名参照が解決する: $src -> $dst「$sec」"
        needle="$dst"$'\t'"$sec"
        case $'\n'"$index"$'\n' in
            *$'\n'"$needle"$'\n'*)
                collect_ok "$label"
                ;;
            *)
                collect_fail "$label" \
                    "参照先ファイルが参照面に無いか、その節見出しが実在しない"
                ;;
        esac
    done < <(printf '%s\n' "$refs")

    collect_finish
}

# Issue #722 AC2 が列挙する検査項目7件。対応表から導出せず固定する。導出すると行が消えた
# ときに期待側も一緒に縮み、欠落が素通りする（面①② が期待リストを固定するのと同じ理由）。
# レイヤ5 は3検査を束ねるため、レイヤ番号の集合の一致だけではこの縮小を捕まえられない。
AC2_CHECK_ITEMS=(
    "レイヤ1 front-matter スキーマ"
    "レイヤ2 index 同期"
    "レイヤ3 相互参照双方向性"
    "レイヤ4 \`Related:\` 参照の生存性・実在性"
    "レイヤ5 ファイル名形式"
    "レイヤ5 識別子重複"
    "レイヤ5 H1 整合"
)

# 第1引数が第2引数以降の集合に完全一致で含まれるか。項目名が空白を含むため、
# 部分文字列照合（`case " ${arr[*]} " in *" $x "*`）では判定できない。
ac2_in_list() {
    local needle="$1"
    shift
    local candidate
    for candidate in "$@"; do
        if [ "$candidate" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

# 末尾の空白を落とす。表のセルは区切りの `|` の手前に空白を持つ。
ac2_rtrim() {
    local v="$1"
    printf '%s' "${v%"${v##*[![:space:]]}"}"
}

@test "面⑥: 検査項目と正本の対応表が7項目を過不足なく持つ" {
    collect_init

    local model="$LINT_MODEL"

    # 対応表の本文行（見出し行・区切り行を除く）を "検査項目|正本" の形で取り出す。
    local rows
    rows="$(sed -n '/^## 検査項目と正本の対応$/,/^## /p' "$model" \
        | sed -n 's/^| *\(レイヤ[0-9][^|]*\)| *\(.*[^ ]\) *|$/\1|\2/p')"

    local nrows=0
    if [ -n "$rows" ]; then
        nrows="$(printf '%s\n' "$rows" | wc -l)"
    fi

    # AC2「表の行数が7である」。重複行の混入もここで落ちる。
    collect_equals "$nrows" "${#AC2_CHECK_ITEMS[@]}" \
        "AC2: 対応表の行数が検査項目数と一致する"

    # 表に現れた検査項目を集める。
    local -a actual_items=()
    local item canon
    while IFS='|' read -r item canon; do
        [ -n "$item" ] || continue
        item="$(ac2_rtrim "$item")"
        actual_items+=("$item")

        # 正本セルが節名参照の形式を取ること（面⑤ の照合に載る形の担保）。
        case "$canon" in
            *'.md`「'*'」'*)
                collect_ok "AC2: 正本セルが節名参照の形式を取る: $item"
                ;;
            *)
                collect_fail "AC2: 正本セルが節名参照の形式を取る: $item" \
                    "正本セルが \`<path>.md\`「<節名>」 形式でない: $canon"
                ;;
        esac
    done < <(printf '%s\n' "$rows")

    # 期待 → 表: 検査項目が対応表から落ちていないこと。
    local expected
    for expected in "${AC2_CHECK_ITEMS[@]}"; do
        if ac2_in_list "$expected" ${actual_items[@]+"${actual_items[@]}"}; then
            collect_ok "AC2: 対応表が検査項目を持つ: $expected"
        else
            collect_fail "AC2: 対応表が検査項目を持つ: $expected" \
                "対応表に当該検査項目の行が無い"
        fi
    done

    # 表 → 期待: 期待リストに無い行が増えていないこと（列挙の宣言なしの追加を防ぐ）。
    local actual
    for actual in ${actual_items[@]+"${actual_items[@]}"}; do
        if ac2_in_list "$actual" "${AC2_CHECK_ITEMS[@]}"; then
            collect_ok "AC2: 対応表の行が期待リストに宣言されている: $actual"
        else
            collect_fail "AC2: 対応表の行が期待リストに宣言されている: $actual" \
                "期待リストに無い検査項目が対応表にある（検査を足したなら期待リストへも足す）"
        fi
    done

    # レイヤ番号の集合が lint-adr.sh のヘッダ宣言と一致すること。
    local table_layers lint_layers
    table_layers="$(printf '%s\n' "$rows" | sed -n 's/^レイヤ\([0-9]\).*/\1/p' | sort -u | tr '\n' ' ')"
    # ヘッダの抽出は面⑦ と同じ型（`lint_header`）を使う。抽出式を2箇所に持つと、
    # 終端の目印が変わったときに片方だけが無言で全文を走査する。
    lint_layers="$(lint_header | sed -n 's/^# レイヤ\([0-9]\).*/\1/p' | sort -u | tr '\n' ' ')"

    if [ -n "$lint_layers" ]; then
        collect_ok "AC2: lint-adr.sh ヘッダからレイヤ宣言を抽出できる（$lint_layers）"
    else
        collect_fail "AC2: lint-adr.sh ヘッダからレイヤ宣言を抽出できる" \
            "ヘッダに「# レイヤN」形式の宣言が1件も無い"
    fi

    collect_equals "$table_layers" "$lint_layers" \
        "AC2: 対応表のレイヤ集合が lint-adr.sh のヘッダ宣言と一致する"

    collect_finish
}

# ---- lint-adr.sh ヘッダのレイヤ1 記述 ----
#
# レイヤ1 が報告する規範（合法な状態の集合）の正本は `adr-model.md`「状態の型」であり、
# ヘッダはその写しを持たない（#794 決定1・決定2）。写しを置いても一致を守る機構は無く、
# 正本を改訂した側だけが動いて静かに乖離する。削除した遷移表と「合法（違反にしない）」の
# 列挙の再混入をここで止める。
#
# ブロックの切り出しは行番号ではなくレイヤ宣言行（`# レイヤN`）で行う。行番号で固定すると、
# ヘッダへ1行足すだけで検査が別の範囲を見る（#787 と同型）。
#
# 【走査面をヘッダ全域に取る理由】
# 写しの再混入は「レイヤ1 ブロックの中に、削除したときと同じ体裁で戻る」とは限らない。
# ブロックの外へ1つずらす／表の体裁を外す／ラベルを言い換える、のいずれでも規範の写しは
# 復活する。したがって「無いこと」の検査はすべてヘッダ全域へ掛け、体裁ではなく
# 値組そのものの形（キーの共起・空欄マーカーの反復・表の区切り）を見る。
# レイヤ1 ブロックに対しては、正本ポインタと違反種別の列挙が在ること（決定2 の「持つ」側）
# だけを確かめる。
LINT_SCRIPT="$PLUGIN_ROOT/scripts/lint-adr.sh"
LINT_MODEL="$MANAGE_ADR_DIR/references/adr-model.md"

# front-matter の3キー。1行に3つ揃えば、それは値組を述べている行である。
LINT_STATE_KEYS=(status validity superseded-by)

# 空欄を表す記法。値組は空の軸を明示するため、1行に2回以上現れる。
LINT_EMPTY_MARKERS=('（無し）' '（空）')

# lint-adr.sh のヘッダ（1行目から `set -euo pipefail` の直前まで）を出す。
lint_header() {
    sed -n '1,/^set -euo pipefail/p' "$LINT_SCRIPT"
}

# ヘッダのうち、レイヤ1 の宣言行から レイヤ2 の宣言行の直前までを出す。
# 一度閉じたら再び開かない。`# レイヤ1` を前方一致で見るため、レイヤが10個目に達すると
# `# レイヤ10` が再びブロックを開いてしまう。
lint_layer1_block() {
    local line inblock=0 closed=0
    while IFS= read -r line; do
        case "$line" in
            '# レイヤ2'*)
                if [ "$inblock" -eq 1 ]; then
                    inblock=0
                    closed=1
                fi
                ;;
            '# レイヤ1'*)
                if [ "$closed" -eq 0 ]; then
                    inblock=1
                fi
                ;;
        esac
        if [ "$inblock" -eq 1 ]; then
            printf '%s\n' "$line"
        fi
    done < <(lint_header)
    return 0
}

# コメント記号と前後の空白を落とした本文を出す。多バイト文字を含むため、awk の文字クラスを
# 使わず bash のリテラル部分文字列操作だけで処理する（mawk はバイト単位に分解して誤判定する）。
lint_comment_body() {
    local body="${1#\#}"
    body="${body#"${body%%[![:space:]]*}"}"
    printf '%s' "${body%"${body##*[![:space:]]}"}"
}

# 文字列に含まれる部分文字列の出現回数を数える。
lint_count_occurrences() {
    # `local a="$1" rest="$a"` と1文で書かない。同一 local 文の右辺は builtin の実行前に
    # 展開されるため、rest には外側スコープの値（通常は空）が入り、数え上げが常に0になる。
    local needle="$2" n=0
    local rest="$1"
    while :; do
        case "$rest" in
            *"$needle"*) : ;;
            *) break ;;
        esac
        rest="${rest#*"$needle"}"
        n=$((n + 1))
    done
    printf '%s' "$n"
}

# 【R1】表の行。本文が `|` を2個以上含む行を出す。行頭の `|` は要求しない。
# 区切りを行頭に置かない書き方（`遷移 | status | validity | superseded-by`）でも同じ表であり、
# 体裁の差でガードを抜けさせない。
lint_scan_table_rows() {
    local line body
    while IFS= read -r line; do
        body="$(lint_comment_body "$line")"
        if [ "$(lint_count_occurrences "$body" '|')" -ge 2 ]; then
            printf '%s\n' "$line"
        fi
    done < <(lint_header)
    return 0
}

# 【R2】3キーを1行で名指す行。値組を述べる行はキーを揃える。
# 違反種別の条件式は1行あたり2キーまでであり（決定2 が「持つ」と定めた側）、ここに掛からない。
lint_scan_key_tuples() {
    local line body k hits
    while IFS= read -r line; do
        body="$(lint_comment_body "$line")"
        hits=0
        for k in "${LINT_STATE_KEYS[@]}"; do
            case "$body" in
                *"$k"*) hits=$((hits + 1)) ;;
            esac
        done
        if [ "$hits" -ge "${#LINT_STATE_KEYS[@]}" ]; then
            printf '%s\n' "$line"
        fi
    done < <(lint_header)
    return 0
}

# 【R3】空欄マーカーを1行で2回以上使う行。キー名を伴わず値だけを並べる書き方
# （`起票 | 提案中 | （無し） | （無し）`）を、表の体裁を外しても落とす。
lint_scan_empty_marker_tuples() {
    local line body m total
    while IFS= read -r line; do
        body="$(lint_comment_body "$line")"
        total=0
        for m in "${LINT_EMPTY_MARKERS[@]}"; do
            total=$((total + $(lint_count_occurrences "$body" "$m")))
        done
        if [ "$total" -ge 2 ]; then
            printf '%s\n' "$line"
        fi
    done < <(lint_header)
    return 0
}

# 【R4】合法な値組の列挙を導くラベル行（本文が「合法」を含み `:` で終わる行）。
# 「空は合法」のような散文は末尾が `:` にならないため拾わない。
lint_scan_legal_set_labels() {
    local line body
    while IFS= read -r line; do
        body="$(lint_comment_body "$line")"
        case "$body" in
            *合法*: | *合法*：) printf '%s\n' "$line" ;;
        esac
    done < <(lint_header)
    return 0
}

# 行数を数える。空文字列は 0 行とする（`printf '%s\n' ""` は 1 行に数えられてしまう）。
lint_count_lines() {
    if [ -z "$1" ]; then
        printf '0'
    else
        printf '%s\n' "$1" | wc -l | tr -d ' '
    fi
}

# 「無いこと」の検査を1件分行う。走査結果が空なら合格、1行でもあれば混入した行を添えて失敗。
lint_collect_absent() {
    local found="$1" label="$2" detail="$3"
    if [ -z "$found" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail 混入した行: $(printf '%s' "$found" | tr '\n' '/')"
    fi
    return 0
}

@test "面⑦: lint-adr.sh ヘッダがレイヤ1 の合法な状態集合を再定義しない" {
    collect_init

    local header block
    header="$(lint_header)"
    block="$(lint_layer1_block)"

    # fail-closed 1: ヘッダの抽出が0行だと、以下の「無いこと」の検査はすべて空振りで
    # 緑になる。抽出結果の非空をここで落とす。
    local nheader
    nheader="$(lint_count_lines "$header")"
    if [ "$nheader" -gt 0 ]; then
        collect_ok "#794: lint-adr.sh のヘッダを抽出できる（$nheader 行）"
    else
        collect_fail "#794: lint-adr.sh のヘッダを抽出できる" \
            "ヘッダの抽出結果が0行（ファイルが読めないか空）"
    fi

    # fail-closed 2: 下端の境界。終端の目印が変わると sed は一致せず本文の末尾まで出し、
    # ヘッダを見ているつもりで実装本体まで見ることになる（範囲が無言で広がる）。
    local header_last
    header_last="$(printf '%s\n' "$header" | tail -n 1)"
    if [ "$header_last" = "set -euo pipefail" ]; then
        collect_ok "#794: ヘッダの抽出が \`set -euo pipefail\` で閉じている"
    else
        collect_fail "#794: ヘッダの抽出が \`set -euo pipefail\` で閉じている" \
            "抽出の最終行が \"$header_last\" であり、終端の目印に届いていない"
    fi

    # fail-closed 3: 上端の境界。`# レイヤ2` が無いとブロックがヘッダ末尾まで伸び、
    # レイヤ1 の範囲を見ているつもりで別の範囲を見ることになる。
    if printf '%s\n' "$header" | grep -q '^# レイヤ2'; then
        collect_ok "#794: レイヤ1 ブロックの上端（\`# レイヤ2\` 宣言）がヘッダにある"
    else
        collect_fail "#794: レイヤ1 ブロックの上端（\`# レイヤ2\` 宣言）がヘッダにある" \
            "ヘッダに \`# レイヤ2\` 宣言が無く、レイヤ1 ブロックの範囲が確定しない"
    fi

    # fail-closed 4: ブロックの抽出が0行なら、以下の「持つ」側の検査が意味を成さない。
    local nblock
    nblock="$(lint_count_lines "$block")"
    if [ "$nblock" -gt 0 ]; then
        collect_ok "#794: レイヤ1 ブロックを抽出できる（$nblock 行）"
    else
        collect_fail "#794: レイヤ1 ブロックを抽出できる" \
            "ヘッダに \`# レイヤ1\` 宣言が無く、ブロックの抽出結果が0行"
    fi

    # 決定2 の「持つ」側。抽出が別の範囲へずれた場合もここで落ちる。
    collect_contains "$block" "レイヤ1違反種別:" \
        "#794: レイヤ1 ブロックが違反種別の列挙を持つ"

    # 決定1: 削除した表の置換先。正本を指すポインタが残っていること。
    collect_contains "$block" 'adr-model.md`「状態の型」' \
        "#794: レイヤ1 ブロックが正本（adr-model.md「状態の型」）を指す"

    # 指し先の実在。節名を改名すると、指す側は静かに壊れるだけで誰も赤にならない。
    # `.sh` 内の節名参照は面⑤ の走査面（manage-adr スキル面）に入らないため、ここで見る。
    if grep -q '^## 状態の型$' "$LINT_MODEL"; then
        collect_ok "#794: 正本ポインタの指す見出し「状態の型」が adr-model.md に実在する"
    else
        collect_fail "#794: 正本ポインタの指す見出し「状態の型」が adr-model.md に実在する" \
            "$LINT_MODEL に \`## 状態の型\` 見出しが無い"
    fi

    # 以下はいずれもヘッダ全域が対象である。ブロックの中だけを見る作りにすると、
    # 写しの置き場所を1つ隣へずらすだけでガードが空振りする。
    lint_collect_absent "$(lint_scan_table_rows)" \
        "#794: ヘッダに表の行（区切りを2個以上持つ行）が無い" \
        "合法な状態の集合の正本は adr-model.md「状態の型」であり、ヘッダは表で定義し直さない。"

    lint_collect_absent "$(lint_scan_key_tuples)" \
        "#794: ヘッダに3キーを1行で並べる行が無い" \
        "status / validity / superseded-by を1行に揃える記述は値組の再定義である。違反種別の条件式は1行あたり2キーまでで書ける。"

    lint_collect_absent "$(lint_scan_empty_marker_tuples)" \
        "#794: ヘッダに空欄マーカーを1行で2回以上使う行が無い" \
        "空の軸を並べて示す記述は、キー名を伴わなくても値組の再定義である。"

    lint_collect_absent "$(lint_scan_legal_set_labels)" \
        "#794: ヘッダが合法な値組の列挙を導かない" \
        "合法な値組は adr-model.md「状態の型」の構成子が定義する。境界事例は違反種別の条件式から読む。"

    collect_finish
}
