#!/usr/bin/env bats
# manage-adr スキル面に対する編集機構の面検査。
#
# 新スキーマの編集機構（decision tree・3段構え対応表）の文書化と旧記述の除去を検査する。
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
    "$MANAGE_ADR_DIR/references/adr-model.md"
    "$MANAGE_ADR_DIR/references/adr-scoping.md"
    "$MANAGE_ADR_DIR/references/cross-references.md"
    "$EDIT_DECISION"
    "$MANAGE_ADR_DIR/references/io-examples.md"
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
    local actual_refs=("$MANAGE_ADR_DIR"/references/*.md)
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

@test "面③: edit-decision.md の内容" {
    collect_init

    local edit_content
    edit_content=$(cat "$EDIT_DECISION" 2>/dev/null || true)

    collect_contains "$edit_content" "3段構え" \
        "AC5: 3段構え編集機構の対応表が edit-decision.md に存在する"
    collect_contains "$edit_content" "些末" \
        "AC5: decision tree（些末/非core/core 判定フロー）が edit-decision.md に存在する"

    collect_finish
}

@test "面④: manage-adr スキル面からの旧節除去" {
    collect_init

    local surface
    surface=$(cat "${AC5_SURFACE_FILES[@]}" 2>/dev/null || true)

    collect_not_contains "$surface" "## モデル制約由来の設計判断インデックス" \
        "AC5: 旧モデル制約由来の設計判断インデックス節が manage-adr スキル面から除去されている"

    collect_finish
}
