#!/usr/bin/env bats
# ADR 分割の逐語照合器（plugins/adr/scripts/verify-split-verbatim.sh）のテスト。
#
# 正例は fixture（scripts/fixtures/verify-split-verbatim/）の2形式（見出し形式・箇条形式）に置く。
# 負例は正例をケースごとの一時ディレクトリへ複写し、1か所だけ変異を入れて作る。変異を
# ケースの中に書くことで、どの1点を崩したときに何が赤くなるかを読めるようにする。
# 検出の側（差分・空の切り出し・行数・網羅性）と免除の側（先頭番号・リード文・番号を持たない
# 非決定文・見出し直後の空行・フェンスの内側の見出し）を対で置く。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# ADR 群をケースごとに変異させるため共有の事前起動はせず、CORPORA は空にする
# （helpers/common.bash の「検査器の起動の型」に従い、ケース内で `run` により起動する）。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/verify-split-verbatim.sh"
CORPORA=()
FIXTURE="$FIXTURES_DIR/verify-split-verbatim"
PRECONDITION_PATHS=("$FIXTURE/heading" "$FIXTURE/list")

H_ORIGINAL="ADR-203101011000-01-original.md"
H_SUCC_A="ADR-203101011100-01-successor-a.md"
H_SUCC_B="ADR-203101011100-02-successor-b.md"
L_ORIGINAL="ADR-203102011000-01-original.md"
L_SUCC="ADR-203102011100-01-successor.md"

setup_file() {
    common_setup_file
}

# fixture の1形式を一時ディレクトリへ複写し、そのパスを返す。
copy_corpus() {
    local kind="$1" dir
    dir="$(mktemp -d "$BATS_TEST_TMPDIR/$kind.XXXXXX")"
    cp "$FIXTURE/$kind"/* "$dir/"
    printf '%s' "$dir"
}

# 1か所の文字列置換を入れる。置換が起きなければケースを失敗させる（変異が空振りした
# まま緑になるのを防ぐ）。多バイト文字を含むため、sed ではなく bash の置換で行う。
mutate() {
    local file="$1" from="$2" to="$3" body
    body="$(cat "$file"; printf x)"
    body="${body%x}"
    if [[ "$body" != *"$from"* ]]; then
        printf '変異の置換元が見つからない: %s in %s\n' "$from" "$file" >&2
        return 1
    fi
    printf '%s' "${body/"$from"/"$to"}" >"$file"
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

@test "正例: 見出し形式の分割が逐語一致し exit 0（先頭番号の違い・リード文・フェンスの内側の見出しは差分にしない）" {
    run_sut "$FIXTURE/heading/$H_ORIGINAL" "$FIXTURE/heading/map.txt"
    collect_init
    collect_rc 0 "見出し形式の正例は exit 0"
    collect_contains "$output" "OK: $H_SUCC_A" "原5→3 の番号の振り直しを含む後継が合格"
    collect_contains "$output" "OK: $H_SUCC_B" "見出し直後の空行が多い後継が合格"
    collect_contains "$output" "転記 4・retire 1・keep 1" "3つの行き先を数える"
    collect_contains "$output" "結果: 合格" "合格を報告する"
    collect_finish
}

@test "正例: 箇条形式の分割が逐語一致し exit 0（項目の後の非決定文は差分にしない）" {
    run_sut "$FIXTURE/list/$L_ORIGINAL" "$FIXTURE/list/map.txt"
    collect_init
    collect_rc 0 "箇条形式の正例は exit 0"
    collect_contains "$output" "OK: $L_SUCC" "字下げした続きを含む項目が合格"
    collect_finish
}

@test "差分: 決定本文の1文字の違いを非0で報告し、差分箇所を出す" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_SUCC_A" "五つ目の決定の本文。" "五つ目の決定の本文、"
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "1文字の差分は exit 1"
    collect_contains "$output" "NG: $H_SUCC_A: 決定本文に差分があります" "差分のある後継を名指す"
    collect_contains "$output" "-五つ目の決定の本文。" "原 ADR 側の行を出す"
    collect_contains "$output" "+五つ目の決定の本文、" "後継側の行を出す"
    collect_contains "$output" "OK: $H_SUCC_B" "差分の無い後継は合格のまま"
    collect_finish
}

@test "差分: 箇条形式の項目の続き（字下げした行）の違いを非0で報告する" {
    local dir
    dir="$(copy_corpus list)"
    mutate "$dir/$L_SUCC" "   空行を挟んで字下げした段落も" "   空行を挟んで字下げした文も"
    run_sut "$dir/$L_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "項目の続きの差分は exit 1"
    collect_contains "$output" "決定本文に差分があります" "差分を報告する"
    collect_finish
}

@test "差分: #### 以下の見出しの節は決定本文に含めて照合する" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_SUCC_A" '`####` 以下の見出しは決定本文に含む。' '`####` 以下の見出しは決定本文に含めない。'
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "#### 配下の差分は exit 1"
    collect_contains "$output" "決定本文に差分があります" "差分を報告する"
    collect_finish
}

@test "差分: 後継にだけある決定（退役する決定の混入）を非0で報告する" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_SUCC_A" "## Consequences" $'### 4. 四つ目の決定（退役する）\n\n四つ目の決定の本文。\n\n## Consequences'
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "後継にだけある決定は exit 1"
    collect_contains "$output" "+### N. 四つ目の決定（退役する）" "混入した決定を差分に出す"
    collect_finish
}

@test "空の切り出し: 後継の見出しの表記ゆれを差分ゼロと判定せず非0にする" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_SUCC_A" "### 3. 五つ目の決定" "### 3 五つ目の決定"
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "後継側が空になる表記ゆれは exit 1"
    collect_contains "$output" "後継に決定 3 が見つかりません" "空になった決定を名指す"
    collect_finish
}

@test "空の切り出し: 原 ADR の見出しの表記ゆれを非0にする" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_ORIGINAL" "### 5. 五つ目の決定" "###5. 五つ目の決定"
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "原 ADR 側が空になる表記ゆれは exit 1"
    collect_contains "$output" "原 ADR に決定 5 が見つかりません" "空になった決定を名指す"
    collect_finish
}

@test "空の切り出し: 対応表が原 ADR に無い決定を指すと非0にする" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/map.txt" "3 ADR-203101011100-02-successor-b 1" "9 ADR-203101011100-02-successor-b 1"
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "対応表の誤りは exit 1"
    collect_contains "$output" "原 ADR に決定 9 が見つかりません" "存在しない決定を名指す"
    collect_contains "$output" "原 ADR の決定 3 が対応表にありません" "取り残された決定を未分類として出す"
    collect_finish
}

@test "空の切り出し: Decision 節が無い・トップレベル決定を書いていない原 ADR を非0にする" {
    local dir
    collect_init

    dir="$(copy_corpus heading)"
    mutate "$dir/$H_ORIGINAL" "## Decision" "## 決定"
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "Decision 節の無い原 ADR は exit 1"
    collect_contains "$output" "\`## Decision\` 節がありません" "節の欠落を報告する"

    dir="$(copy_corpus list)"
    mutate "$dir/$L_ORIGINAL" "1. **一つ目**" "**一つ目**"
    mutate "$dir/$L_ORIGINAL" "2. **二つ目**" "**二つ目**"
    mutate "$dir/$L_ORIGINAL" "3. **三つ目**" "**三つ目**"
    run_sut "$dir/$L_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "番号の無い原 ADR は exit 1"
    collect_contains "$output" "1件も切り出せません" "切り出しの失敗を報告する"
    collect_finish
}

@test "行数: 後継の決定へ1行足すと、行数の不一致を報告して非0にする" {
    local dir
    dir="$(copy_corpus heading)"
    mutate "$dir/$H_SUCC_B" "三つ目の決定の本文。" $'三つ目の決定の本文。\n書き足した行。'
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_init
    collect_rc 1 "行数の不一致は exit 1"
    collect_contains "$output" "NG: $H_SUCC_B: 行数が一致しません（原 ADR 側 3 行・後継側 4 行）" "両辺の行数を出す"
    collect_finish
}

@test "網羅性: 未分類・行き先の重複・転記の行が無い対応表を非0にする" {
    local dir
    collect_init

    dir="$(copy_corpus heading)"
    mutate "$dir/map.txt" $'6 keep\n' ""
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "未分類の決定は exit 1"
    collect_contains "$output" "原 ADR の決定 6 が対応表にありません（未分類）" "未分類を名指す"

    dir="$(copy_corpus heading)"
    mutate "$dir/map.txt" "4 retire" $'4 retire\n4 keep'
    run_sut "$dir/$H_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "行き先の重複は exit 1"
    collect_contains "$output" "原 ADR の決定 4 が対応表に2回以上あります" "重複を名指す"

    dir="$(copy_corpus list)"
    printf '1 retire\n2 keep\n3 retire\n' >"$dir/map.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "照合する後継が無い対応表は exit 1"
    collect_contains "$output" "逐語転記の行がありません" "何も照合しないまま合格にしない"

    dir="$(copy_corpus list)"
    printf '# 行が無い\n\n' >"$dir/map.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/map.txt"
    collect_rc 1 "空の対応表は exit 1"
    collect_finish
}

@test "入力の誤り: 引数・ファイル・対応表の書式の誤りを exit 2 で止める" {
    local dir
    collect_init
    dir="$(copy_corpus list)"

    run_sut "$dir/$L_ORIGINAL"
    collect_rc 2 "引数が1つなら exit 2"

    run_sut "$dir/no-such.md" "$dir/map.txt"
    collect_rc 2 "原 ADR が無ければ exit 2"

    run_sut "$dir/$L_ORIGINAL" "$dir/no-such.txt"
    collect_rc 2 "対応表が無ければ exit 2"

    printf '1 ADR-203102011100-01-successor\n' >"$dir/bad-fields.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/bad-fields.txt"
    collect_rc 2 "欄の数が合わない行は exit 2"

    printf '1 discard\n' >"$dir/bad-word.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/bad-word.txt"
    collect_rc 2 "retire / keep 以外の語は exit 2"

    printf '1 ./ADR-203102011100-01-successor 1\n' >"$dir/bad-path.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/bad-path.txt"
    collect_rc 2 "後継をパスで書いた行は exit 2"

    printf '1 ADR-203102011100-09-missing 1\n' >"$dir/bad-missing.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/bad-missing.txt"
    collect_rc 2 "原 ADR と同じディレクトリに無い後継は exit 2"

    printf 'x ADR-203102011100-01-successor 1\n' >"$dir/bad-number.txt"
    run_sut "$dir/$L_ORIGINAL" "$dir/bad-number.txt"
    collect_rc 2 "数字でない原決定番号は exit 2"
    collect_finish
}
