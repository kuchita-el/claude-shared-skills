#!/usr/bin/env bats
# 配布物（adr プラグイン）が配布元のテスト実行経路の表記を持たないことの機械検査。
#
# 【主題】配布物と配布元の境界は一方向（配布物は配布元の資産を知らない）である
# （docs/distribution-boundary.md §3）。本ファイルはその一方向性のうち、配布元の
# テスト実行経路を指す語彙（scripts/tests/・scripts/fixtures/・fixtures/・run-tests・
# .bats）が配布物のテキストへ混入していないことを検査する。
#
# 【走査語彙の限界】語彙は上記5種に固定であり、リストに無い新種の表記（例えば別名の
# テストディレクトリや別のテストランナー名）は検出できない。
#
# 【独立スクリプトへ切り出さなかった理由】走査の実体は再帰 grep 1本であり、
# scripts/*.sh へ切り出すだけの内容量がない。切り出すと runner の SUITES へ登録するか
# 否かの二択が生じ、登録すれば bats 経由と直接実行で走査が二重化し、登録しなければ
# runner から一度も起動されないスクリプトが増える。`.bats` には EXPECTED_BATS による
# 双方向照合があるが scripts/*.sh には無く、未登録経路の検出漏れを防げない。
#
# 【判定形（決定論点）】語彙には包含関係がある。scripts/fixtures/ に一致する文字列は
# 必ず fixtures/ にも一致する。一致1件をラベルへ帰属させず単に語彙集合を連結して
# 走査すると、scripts/fixtures/ を語彙から落としても同じ行が fixtures/ で当たり、
# 変異が無検出のまま通る。そこで一致1件を
# "<用語ラベル><TAB><走査根からの相対パス>:<行番号>:<行本文>" の1行として出力し、
# 判定側はラベルを行頭に固定した1本の文字列として照合する（`collect_contains`）。
# 併せて一致行の本数も照合する（`collect_equals`）。ラベル・パス・行本文を別々の
# 部分文字列として照合すると、行本文に残った文字列で偶然一致し、この変異検出が
# 空振りする。
#
# 【配置】docs/distribution-boundary.md が配布物と配布元の境界の正本。
# docs/development/test-execution.md §1 が本ファイルの走行位置を記す。
#
# 【ADR化の判定】本ファイルが新たに決めた設計判断（置き場所・語彙の保持形・判定形・
# 包含関係のある語彙への変異検出の担保）は manage-adr スキルの ADR 化判定基準（必要条件
# と粒度判定基準4項目）の必要条件は満たすが、粒度判定基準の点数は境界未満（後戻りコストが
# 閾値未満・適用先が新設検査1本のみ・理由の保持先がこのコメントとプランで揮発しない）
# のため ADR化しない。

load 'helpers/common'

PRECONDITION_PATHS=("$PLUGIN_ROOT")

setup_file() {
    common_setup_file
}

# 走査根の既定値解決だけを担う。scan_distribution_boundary はこれを内部で呼ぶ。
# 単独でも呼べるようにするのは、「引数省略時の走査根が PLUGIN_ROOT と一致する」ことを
# 走査本体の grep 結果と切り離して同定するため。
resolve_scan_root() {
    printf '%s\n' "${1:-$PLUGIN_ROOT}"
}

# 走査関数（本ファイルの被テスト対象）。
#   引数: 走査根（省略時は配布物のルート）
#   出力: 一致1件ごとに "<用語ラベル><TAB><相対パス>:<行番号>:<行本文>" を1行
#   終了コード: 0=一致なし / 1=一致あり（全件出力） / 2=前提不成立（走査根が無い・0件）
scan_distribution_boundary() {
    local root
    root="$(resolve_scan_root "${1:-}")"

    if [ ! -d "$root" ]; then
        printf '走査根が存在しない、またはディレクトリでない: %s\n' "$root" >&2
        return 2
    fi

    local -a files=()
    local f
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(find "$root" -type f -print0)

    if [ "${#files[@]}" -eq 0 ]; then
        printf '走査根の配下にファイルが1件も無い: %s\n' "$root" >&2
        return 2
    fi

    # 用語ラベル + 検出パターンの対。1語ずつ走査し、一致をラベルへ帰属させる。
    # 5語を1本の正規表現へ連結しない（上記コメント「判定形」参照）。
    local -a term_labels=(
        'scripts/tests/'
        'scripts/fixtures/'
        'fixtures/'
        'run-tests'
        '.bats'
    )

    local label rel line matched=0
    for label in "${term_labels[@]}"; do
        for f in "${files[@]}"; do
            rel="${f#"$root"/}"
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                printf '%s\t%s:%s\n' "$label" "$rel" "$line"
                matched=1
            done < <(grep -InF -- "$label" "$f" 2>/dev/null)
        done
    done

    [ "$matched" -eq 1 ] && return 1
    return 0
}

@test "前提: 配布物のルートが存在する" {
    assert_preconditions_met
}

@test "面①: 既定の走査根は配布物のルートであり、混入なしで exit 0 になる" {
    collect_init

    run resolve_scan_root
    collect_equals "$output" "$PLUGIN_ROOT" "既定の走査根が PLUGIN_ROOT と一致する"

    run scan_distribution_boundary
    collect_rc 0 "引数省略時、混入のない配布物に対する走査が exit 0 で終わる"

    local file_count
    file_count="$(find "$PLUGIN_ROOT" -type f | wc -l)"
    if [ "$file_count" -ge 1 ]; then
        collect_ok "走査対象ファイル数が1件以上である"
    else
        collect_fail "走査対象ファイル数が1件以上である" "実測: $file_count"
    fi

    if grep -Eq '"name"[[:space:]]*:[[:space:]]*"adr"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null; then
        collect_ok "走査根直下の plugin.json の name が adr である"
    else
        collect_fail "走査根直下の plugin.json の name が adr である" "$PLUGIN_ROOT/.claude-plugin/plugin.json を確認できない、または name が adr でない"
    fi

    collect_finish
}

# 配布物の複製へ走査語彙を混入させ、検出できることを確認する。
# 複製は BATS_TEST_TMPDIR 配下に作り、配布物本体（PLUGIN_ROOT）は一切書き換えない。
# 混入は各項目ごとに複製を作り直して1件だけに保つ。
@test "面②: 走査語彙の混入を検出する" {
    collect_init

    # 対照: 混入を加えていない複製は exit 0（負例が空振りでも赤に見える事態を防ぐ）
    local control_dup="$BATS_TEST_TMPDIR/control"
    mkdir -p "$control_dup"
    cp -r "$PLUGIN_ROOT"/. "$control_dup"/
    run scan_distribution_boundary "$control_dup"
    collect_rc 0 "対照: 混入のない複製は exit 0"

    # 語彙5種それぞれについて、README.md の末尾へ1行だけ混入させる
    local label content expect_count
    local -a labels=('scripts/tests/' 'scripts/fixtures/' 'fixtures/' 'run-tests' '.bats')
    local -a contents=(
        '詳細は scripts/tests/ を参照'
        '詳細は scripts/fixtures/ を参照'
        '詳細は fixtures/ を参照'
        '検証は run-tests で行う'
        '検証は distribution-boundary.bats で行う'
    )
    local -a expect_counts=(1 2 1 1 1)

    local i
    for i in "${!labels[@]}"; do
        label="${labels[$i]}"
        content="${contents[$i]}"
        expect_count="${expect_counts[$i]}"

        local dup="$BATS_TEST_TMPDIR/vocab-$i"
        mkdir -p "$dup"
        cp -r "$PLUGIN_ROOT"/. "$dup"/
        printf '%s\n' "$content" >>"$dup/README.md"
        local line_no
        line_no="$(grep -nF -- "$content" "$dup/README.md" | tail -1 | cut -d: -f1)"

        run scan_distribution_boundary "$dup"
        collect_rc 1 "語彙「$label」の混入は非0で終わる"

        local actual_count=0
        [ -n "$output" ] && actual_count="$(wc -l <<<"$output")"
        collect_equals "$actual_count" "$expect_count" "語彙「$label」の混入は一致行が $expect_count 本になる"

        local needle="${label}"$'\t'"README.md:${line_no}:${content}"
        collect_contains "$output" "$needle" "語彙「$label」の一致行がラベル・所在・行本文の組で出力される"
    done

    # 新規ファイル経路: 除外リストを持たない設計が新規ファイルも自動的に覆うことの確認
    local newfile_dup="$BATS_TEST_TMPDIR/newfile"
    mkdir -p "$newfile_dup"
    cp -r "$PLUGIN_ROOT"/. "$newfile_dup"/
    printf '%s\n' '詳細は scripts/tests/ を参照' >"$newfile_dup/new-note.md"
    run scan_distribution_boundary "$newfile_dup"
    collect_rc 1 "新規ファイルへの混入は非0で終わる"
    collect_contains "$output" "scripts/tests/"$'\t'"new-note.md:1:詳細は scripts/tests/ を参照" "新規ファイル new-note.md の一致行が出力される"

    # 拡張子なしファイル経路: 拡張子で絞らない設計であることの確認（Issue 決定2）
    local noext_dup="$BATS_TEST_TMPDIR/noext"
    mkdir -p "$noext_dup"
    cp -r "$PLUGIN_ROOT"/. "$noext_dup"/
    local noext_content='# 詳細は scripts/tests/ を参照'
    printf '%s\n' "$noext_content" >>"$noext_dup/hooks/adr-commit-gate"
    local noext_line_no
    noext_line_no="$(grep -nF -- "$noext_content" "$noext_dup/hooks/adr-commit-gate" | tail -1 | cut -d: -f1)"
    run scan_distribution_boundary "$noext_dup"
    collect_rc 1 "拡張子を持たないファイルへの混入は非0で終わる"
    collect_contains "$output" "scripts/tests/"$'\t'"hooks/adr-commit-gate:${noext_line_no}:${noext_content}" "拡張子なしファイル hooks/adr-commit-gate の一致行が出力される"

    collect_finish
}

@test "面③: 走査根の前提が崩れたとき、0件照合を緑にせず fail-closed で終わる" {
    collect_init

    run scan_distribution_boundary "$BATS_TEST_TMPDIR/does-not-exist"
    collect_rc 2 "走査根が存在しない場合、前提不成立として exit 2 で終わる"

    local empty_dir="$BATS_TEST_TMPDIR/empty-root"
    mkdir -p "$empty_dir"
    run scan_distribution_boundary "$empty_dir"
    collect_rc 2 "走査根の配下にファイルが1件も無い場合、前提不成立として exit 2 で終わる"

    collect_finish
}
