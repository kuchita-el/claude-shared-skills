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
# 照合件数の下限を明示するのは、抽出が空振りしたとき（形式変更・パーサの退行）に
# 0件照合のまま緑になるのを防ぐため。

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

    # 抽出が空振りしたまま緑になるのを防ぐ下限。
    if [ "$total" -ge 1 ]; then
        collect_ok "AC5: 節名参照の照合件数が下限を満たす（$total 件）"
    else
        collect_fail "AC5: 節名参照の照合件数が下限を満たす" \
            "節名参照を1件も抽出できていない（抽出の退行か形式変更）"
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

@test "面⑥: 検査項目と正本の対応表が lint-adr.sh のレイヤ宣言を過不足なく覆う" {
    collect_init

    local model="$MANAGE_ADR_DIR/references/adr-model.md"
    local lint="$PLUGIN_ROOT/scripts/lint-adr.sh"

    # 対応表の本文行（見出し行・区切り行を除く）を取り出す。
    local rows
    rows="$(sed -n '/^## 検査項目と正本の対応$/,/^## /p' "$model" \
        | sed -n 's/^| *\(レイヤ[0-9][^|]*\)| *\(.*[^ ]\) *|$/\1|\2/p')"

    local nrows=0
    if [ -n "$rows" ]; then
        nrows="$(printf '%s\n' "$rows" | wc -l)"
    fi

    if [ "$nrows" -ge 1 ]; then
        collect_ok "AC5: 対応表の行を抽出できる（$nrows 行）"
    else
        collect_fail "AC5: 対応表の行を抽出できる" \
            "「検査項目と正本の対応」表の行を1件も抽出できていない（節の削除・改名・形式変更）"
    fi

    # 各行の正本セルが `<path>.md`「<節名>」 形式であること（面⑤ の照合に載る形の担保）。
    local item source
    while IFS='|' read -r item source; do
        [ -n "$item" ] || continue
        case "$source" in
            *'.md`「'*'」'*)
                collect_ok "AC5: 対応表の正本セルが節名参照の形式を取る: ${item% }"
                ;;
            *)
                collect_fail "AC5: 対応表の正本セルが節名参照の形式を取る: ${item% }" \
                    "正本セルが \`<path>.md\`「<節名>」 形式でない: $source"
                ;;
        esac
    done < <(printf '%s\n' "$rows")

    # レイヤ番号の集合が lint-adr.sh のヘッダ宣言と一致すること。
    local table_layers lint_layers
    table_layers="$(printf '%s\n' "$rows" | sed -n 's/^レイヤ\([0-9]\).*/\1/p' | sort -u | tr '\n' ' ')"
    lint_layers="$(sed -n '1,/^set -euo pipefail/p' "$lint" \
        | sed -n 's/^# レイヤ\([0-9]\).*/\1/p' | sort -u | tr '\n' ' ')"

    if [ -n "$lint_layers" ]; then
        collect_ok "AC5: lint-adr.sh ヘッダからレイヤ宣言を抽出できる（$lint_layers）"
    else
        collect_fail "AC5: lint-adr.sh ヘッダからレイヤ宣言を抽出できる" \
            "ヘッダに「# レイヤN」形式の宣言が1件も無い"
    fi

    collect_equals "$table_layers" "$lint_layers" \
        "AC5: 対応表のレイヤ集合が lint-adr.sh のヘッダ宣言と一致する"

    collect_finish
}
