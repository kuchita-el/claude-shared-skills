#!/usr/bin/env bats
# 固定題材集合の実行支援スクリプト（plugins/adr/scripts/adr-scoping-cases.sh）のテスト（基本系）。
#
# scripts/fixtures/adr-scoping-cases/ 配下の fixture を題材集合ディレクトリとして被テスト
# スクリプトへ末尾引数で渡し、exit code と出力の部分一致を検査する。
#
# 環境操作を伴うケース（awk の代役・$TMPDIR の異常・診断の走査順・配布物の非依存性）は
# adr-scoping-cases-edge.bats が持つ。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# corpus はサブコマンドと fixture の組み合わせごとに異なり事前起動を共有できないため、
# 共有 setup_file の CORPORA は空にし、検査器の起動は各ケース内で bats 組み込みの `run` に
# より行う（helpers/common.bash の「検査器の起動の型」に従う）。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/adr-scoping-cases.sh"
CASES_DIR="$FIXTURES_DIR/adr-scoping-cases"
JUDGMENTS_DIR="$CASES_DIR/judgments"

# 対象文書は prompt がパスを差し込むだけで中身を読まないため、リポジトリ内の安定した
# 実在ファイルであれば足りる。被テスト対象の判定手続き文書を指す必要は無い。
DOC="$REPO_ROOT/CLAUDE.md"
MISSING_DOC="$REPO_ROOT/この対象文書は存在しない.md"
MISSING_DIR="$CASES_DIR/この題材集合ディレクトリは存在しない"

CORPORA=()
PRECONDITION_PATHS=("$CASES_DIR/valid" "$JUDGMENTS_DIR" "$DOC")

setup_file() {
    common_setup_file
}

# パーミッションを変えたディレクトリ・ファイルが残ったままだと、bats の tmpdir 掃除自体が
# 失敗する。各ケース内でも戻しているが、途中で abort した場合に備えて teardown でも
# 一括で戻す（teardown は errexit で abort した @test の後でも走る）。
teardown() {
    [ -n "${BATS_TEST_TMPDIR:-}" ] || return 0
    chmod -R u+rwX "$BATS_TEST_TMPDIR" 2>/dev/null || true
    return 0
}

# ---------------------------------------------------------------- 判定の部品

# 被テストスクリプトを実行し、標準出力と標準エラーを合わせて $output に、
# exit code を $status に置く。
sc() {
    run bash "$SUT" "$@" </dev/null
}

# 標準出力だけを $output に捕捉する（prompt が返すパスを取るために使う）。
sc_stdout() {
    run --separate-stderr bash "$SUT" "$@" </dev/null
}

# 作業ディレクトリを変えてから実行する（相対パスを引数として渡す検査で使う）。
#
# cd に失敗したら SUT を起動できない。ここで黙って戻ると $status / $output に直前の
# 実行結果が残り、呼び出し側の判定がその値を読んで緑のまま素通りする（fail-open）。
# 失敗が分かる値へ明示的に置き換えてから戻す。復路の cd 失敗は以降の実行が別ディレクトリで
# 走ることを意味するため、握り潰さずケースを落とす。
sc_in() {
    local dir="$1" prev="$PWD"
    shift
    cd "$dir" || {
        status=127
        output="cd に失敗した: $dir"
        return 0
    }
    run bash "$SUT" "$@" </dev/null
    cd "$prev" || return 1
    return 0
}

sc_stdout_in() {
    local dir="$1" prev="$PWD"
    shift
    cd "$dir" || {
        status=127
        output="cd に失敗した: $dir"
        return 0
    }
    run --separate-stderr bash "$SUT" "$@" </dev/null
    cd "$prev" || return 1
    return 0
}

# 直前の実行結果を収集する。$1 期待 exit code / $2 ラベル / $3 以降 出力に含まれるべき文字列
collect_run() {
    local want_rc="$1" label="$2"
    shift 2
    local ok=1 detail="" p
    if [ "$status" -ne "$want_rc" ]; then
        ok=0
        detail="exit code 期待 $want_rc / 実際 $status"
    fi
    for p in "$@"; do
        case "$output" in
            *"$p"*) ;;
            *) ok=0 detail="${detail}${detail:+ / }出力に含まれない: $p" ;;
        esac
    done
    if [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail"$'\n       出力:\n'"$output"
    fi
    return 0
}

# 与えた文字列に部分文字列が含まれることだけを収集する。$1 対象文字列 / $2 ラベル / $3 以降 含まれるべき文字列
collect_out() {
    local text="$1" label="$2"
    shift 2
    local ok=1 detail="" p
    for p in "$@"; do
        case "$text" in
            *"$p"*) ;;
            *) ok=0 detail="${detail}${detail:+ / }出力に含まれない: $p" ;;
        esac
    done
    if [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail"$'\n       出力:\n'"$text"
    fi
    return 0
}

# valid fixture の3点セットを複製した題材集合ディレクトリを作る。
copy_valid_case_dir() {
    local dest="$1"
    mkdir -p "$dest"
    cp "$CASES_DIR/valid/cases.md" "$CASES_DIR/valid/expectations.tsv" \
        "$CASES_DIR/valid/prompt-template.md" "$dest/"
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

# ---------------------------------------------------------------- validate 系

@test "面①: validate valid が exit 0" {
    collect_init
    sc validate "$CASES_DIR/valid"
    collect_run 0 "01. validate valid → exit 0"
    collect_finish
}

@test "面②: validate 必須項目の欠落" {
    collect_init

    sc validate "$CASES_DIR/missing-id"
    collect_run 1 "02. validate missing-id → exit 1、CASE-A2 の対応行が無いことを診断として告げ、違反1件と数える" \
        "expectations.tsv に対応する行が無い題材: CASE-A2" "違反 1 件"

    sc validate "$CASES_DIR/missing-origin"
    collect_run 1 "03. validate missing-origin → exit 1、CASE-A2 と由来の未記入を告げる" "CASE-A2" "由来"

    sc validate "$CASES_DIR/missing-asset-type"
    collect_run 1 "04. validate missing-asset-type → exit 1、CASE-A2 と資産種別の未記入を告げる" "CASE-A2" "資産種別"

    sc validate "$CASES_DIR/missing-carrier"
    collect_run 1 "05. validate missing-carrier → exit 1、CASE-A2 と担い方の未記入を告げる" "CASE-A2" "担い方"

    sc validate "$CASES_DIR/missing-layer"
    collect_run 1 "06. validate missing-layer → exit 1、CASE-A2 と3層の欠落を告げる" "CASE-A2" "3層"

    collect_finish
}

@test "面③: validate は prompt-template.md の欠落を見ない" {
    collect_init
    sc validate "$CASES_DIR/no-template"
    collect_run 0 "07. validate no-template → exit 0（prompt-template.md の欠落は validate では見ない）"
    collect_finish
}

# 引数とパスの異常系をまとめて押さえる。誤検出回避（実行のみ可のディレクトリを弾かない）も
# 同じ面に置く。`-` 始まり・`var=value` 形・空文字列・辿れないディレクトリは、いずれも
# 「原因を取り違えた診断で落ちる」という同型の欠陥であり、検査意図が同一である。
@test "面④: validate 引数・パスの異常と誤検出回避" {
    collect_init

    sc validate
    collect_run 2 "08. validate（題材集合ディレクトリの省略）→ exit 2、使い方を示す" "使い方"

    # exit code だけを見ると、存在検査を落としても後続のファイル存在検査が別理由で
    # exit 2 を返すため検査が通ってしまう。理由を名指しする診断文まで押さえる。
    sc validate "$MISSING_DIR"
    collect_run 2 "09. validate（存在しない題材集合ディレクトリ）→ exit 2、ディレクトリが存在しないことを理由として告げる" \
        "題材集合ディレクトリが存在しない"

    # 題材集合ディレクトリ名が `-` で始まる場合、ファイル引数がコマンドのオプションとして
    # 解釈されてはならない。`grep` は `--` を置かないと `-dash/cases.md` を
    # `--directories=ash/cases.md` と読み、題材ID の列挙が空になって
    # 「cases.md に題材が1件も無い」という原因を取り違えた診断で落ちる。
    # `awk` に `--` は置けない（置くと `--` 自体をファイル名として開きにいって落ちる）ので、
    # 両者を混ぜないこと。ただし `awk` が安全というわけではなく、オペランドの扱いが違うだけ
    # である。`awk` は先頭 `-` をオプションと読まない代わりに `name=value` の形を変数代入と
    # 読む（09b で押さえる）。どちらの型も検査器側はパスの正規化で塞いでいる。
    local dash_parent="$BATS_TEST_TMPDIR/dash-parent"
    local dash_label="09a. validate/prompt（題材集合ディレクトリ名が - で始まる）→ ファイル引数をオプションと読まずに通す"
    local dash_ok=1 dash_detail=""
    copy_valid_case_dir "$dash_parent/-dash"
    sc_in "$dash_parent" validate -dash
    [ "$status" -eq 0 ] || { dash_ok=0 dash_detail="validate: rc=$status / $output"; }
    sc_stdout_in "$dash_parent" prompt "$dash_parent/-dash/cases.md" CASE-A1 -dash
    if [ "$status" -ne 0 ] || [ ! -f "$output" ]; then
        dash_ok=0
        dash_detail="${dash_detail}${dash_detail:+ / }prompt: rc=$status / out=$output"
    else
        case "$(cat "$output")" in
            *"コミットを止める"*) ;;
            *) dash_ok=0 dash_detail="${dash_detail}${dash_detail:+ / }prompt: 題材文が差し込まれていない" ;;
        esac
        rm -f "$output"
    fi
    [ "$dash_ok" -eq 1 ] && collect_ok "$dash_label" || collect_fail "$dash_label" "$dash_detail"

    # awk はオペランドのうち `name=value` の形をしたものを変数代入として解釈する。
    # `a=b` のような相対パスをそのまま渡すとファイルを開かずに標準入力を読みにいき、
    # 診断ゼロのまま偽の違反が並ぶ（先頭 `-` の場合と同じ「原因の取り違え」の型で、
    # `--` では塞がらない）。パスを `./` 前置へ正規化することで閉じる。
    #
    # 正規化は4引数に入っているが、**awk のオペランドへ実際に渡るのは3経路**である
    # （validate の題材集合ディレクトリ・report の判定記録TSV・prompt の題材集合
    # ディレクトリ）。1経路だけを見ると残りの正規化を外す変異が緑のまま通るため、
    # 4引数すべてを var=value 形で渡し、この3経路を単独変異で殺せる状態にしてある。
    #
    # 残る1つ——report の題材集合ディレクトリ——は現状デッドな予防的硬化である。
    # 集計 awk は expectations.tsv を `expfile` の環境変数渡し＋`getline < expfile` で
    # 読み、題材IDの一覧は `list_case_ids` の `grep --` 経由で得るため、この値は
    # awk のオペランドに一度も現れない。したがって**この経路の正規化を外す変異は
    # 本アサーションでは殺せない**（実行時の挙動は変わらないため実害も無い）。
    # `expfile` をオペランド渡しへ寄せるリファクタを入れると load-bearing になるので、
    # そのときは判定記録TSV と同じ形で4経路目の検査をここへ足すこと。
    local eq_parent="$BATS_TEST_TMPDIR/eq-parent"
    local eq_label="09b. validate/report/prompt（題材集合ディレクトリ名・判定記録TSV 名が var=value 形）→ awk が変数代入と読まず、偽の違反も原因の取り違えも出さない"
    local eq_ok=1 eq_detail=""
    copy_valid_case_dir "$eq_parent/a=b"
    cp "$JUDGMENTS_DIR/valid-judgments.tsv" "$eq_parent/j=1.tsv"
    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline="$output"
    [ "$status" -eq 0 ] || { eq_ok=0 eq_detail="baseline report: rc=$status / $output"; }
    sc_in "$eq_parent" validate 'a=b'
    [ "$status" -eq 0 ] || { eq_ok=0 eq_detail="validate: rc=$status / $output"; }
    sc_in "$eq_parent" report 'j=1.tsv' 'a=b'
    [ "$status" -eq 0 ] || { eq_ok=0 eq_detail="${eq_detail}${eq_detail:+ / }report: rc=$status"; }
    [ "$output" = "$baseline" ] || eq_ok=0 eq_detail="${eq_detail}${eq_detail:+ / }report: baseline と出力が一致しない"
    sc_stdout_in "$eq_parent" prompt "$DOC" CASE-A1 'a=b'
    if [ "$status" -ne 0 ] || [ ! -f "$output" ]; then
        eq_ok=0
        eq_detail="${eq_detail}${eq_detail:+ / }prompt: rc=$status / out=$output"
    else
        # 題材文を読めていないと「題材文が空である」で落ちる（原因の取り違え）。
        case "$(cat "$output")" in
            *"コミットを止める"*) ;;
            *) eq_ok=0 eq_detail="${eq_detail}${eq_detail:+ / }prompt: 題材文が差し込まれていない" ;;
        esac
        rm -f "$output"
    fi
    [ "$eq_ok" -eq 1 ] && collect_ok "$eq_label" || collect_fail "$eq_label" "$eq_detail"

    # 正規化が空文字列を `./` へ化けさせると、引数を空で渡した呼び出しがカレント
    # ディレクトリを指す正常な入力になり、usage が明記する「既定値を持たない」が破れる。
    # 題材集合ディレクトリの中から実行すれば、検査が通ってしまうことがそのまま観測できる。
    local empty_parent="$BATS_TEST_TMPDIR/empty-parent"
    local empty_label="09d. validate/report/prompt（引数が空文字列）→ カレントディレクトリを既定値にせず、指定されていないことを名指しする"
    copy_valid_case_dir "$empty_parent"
    cp "$JUDGMENTS_DIR/valid-judgments.tsv" "$empty_parent/j.tsv"
    # 空を渡す引数の位置ごとに1回ずつ。`report` は判定記録TSV も正規化を通るため2回見る。
    # 末尾の空引数は配列へ畳むと落ちるため、呼び出しを展開して書く。
    EMPTY_OK=1
    EMPTY_DETAIL=""
    expect_empty_rejected "$empty_parent" "validate/dir" validate ""
    expect_empty_rejected "$empty_parent" "report/dir" report j.tsv ""
    expect_empty_rejected "$empty_parent" "report/tsv" report "" .
    expect_empty_rejected "$empty_parent" "prompt/dir" prompt "$DOC" CASE-A1 ""
    [ "$EMPTY_OK" -eq 1 ] && collect_ok "$empty_label" || collect_fail "$empty_label" "$EMPTY_DETAIL"

    # ディレクトリを辿れないと配下の `[ -f ]` が軒並み偽になり、実在するファイルが
    # 「欠けている」と報告される。ファイル単位の可読性検査と同じ型の取り違えである。
    #
    # 検査は `[ -x "$dir" ]` の1本である。000（読めも辿れもしない）と 666（読めるが
    # 辿れない）の2モードを持つのは、後者が「`-r` を足しても意味が無い」ことを示す枝で
    # あるため。`-x` を外す変異はどちらの枝でも落ちる。
    check_unreadable_case_dir 09c 000 "読めず辿れもしない" \
        "09c. validate（題材集合ディレクトリを読めず辿れもしない）→ 辿れないことを名指しする（ファイルの欠落へ化けない）"
    check_unreadable_case_dir 09e 666 "読めるが辿れない" \
        "09e. validate（題材集合ディレクトリを読めるが辿れない）→ 辿れないことを名指しする（ファイルの欠落へ化けない）"

    # 上の連言から `-r` を落とした判断を、正の側から固定する。実行のみ可（mode 111）は
    # 一覧できないだけで既知の名前は開けるため、本スクリプトの用途では正常に動く。
    # `-r` を検査へ足し戻すと、動く構成を弾くようになって本アサーションが落ちる。
    local xo_dir="$BATS_TEST_TMPDIR/execonly/dir"
    local xo_label="09f. validate（題材集合ディレクトリが実行のみ可）→ 動く構成を弾かずに検査を通す"
    copy_valid_case_dir "$xo_dir"
    chmod 111 "$xo_dir"
    if [ -r "$xo_dir" ]; then
        # root 実行等で読めてしまう環境では成立しない検査なので、その旨を告知して飛ばす
        collect_skipped "$xo_label" "chmod 111 でも読める環境のため未実行"
    else
        sc validate "$xo_dir"
        if [ "$status" -eq 0 ]; then
            collect_ok "$xo_label"
        else
            collect_fail "$xo_label" "exit code 期待 0 / 実際 $status / $output"
        fi
    fi
    # bats の tmpdir 掃除が失敗しないよう、パーミッションを必ず戻す。
    chmod 755 "$xo_dir"

    collect_finish
}

# 面④の下請け。空文字列の引数が既定値（カレントディレクトリ）へ畳まれないことを検査する。
# 結果は EMPTY_OK / EMPTY_DETAIL へ積み、1件目で打ち切らない。
expect_empty_rejected() {
    local dir="$1" name="$2"
    shift 2
    sc_in "$dir" "$@"
    [ "$status" -eq 2 ] || EMPTY_OK=0 EMPTY_DETAIL="${EMPTY_DETAIL}${EMPTY_DETAIL:+ / }$name: exit code 期待 2 / 実際 $status"
    case "$output" in
        *"が指定されていない"*) ;;
        *) EMPTY_OK=0 EMPTY_DETAIL="${EMPTY_DETAIL}${EMPTY_DETAIL:+ / }$name: 指定されていないことを名指ししていない" ;;
    esac
    return 0
}

# 面④の下請け。読めない／辿れない題材集合ディレクトリの2モードを同じ手順で検査する。
check_unreadable_case_dir() {
    local id="$1" mode="$2" why="$3" label="$4"
    local dir="$BATS_TEST_TMPDIR/unreadable-$id/dir"
    copy_valid_case_dir "$dir"
    chmod "$mode" "$dir"
    # root は権限ビットを無視して辿れてしまうため、実際に塞がっているときだけ判定する。
    if [ -x "$dir" ]; then
        collect_skipped "$label" "chmod $mode でも辿れる環境のため未実行"
    else
        sc validate "$dir"
        local ok=1 detail=""
        [ "$status" -eq 2 ] || { ok=0 detail="exit code 期待 2 / 実際 $status"; }
        case "$output" in
            *"題材集合ディレクトリを辿れない"*) ;;
            *) ok=0 detail="${detail}${detail:+ / }辿れないことを名指ししていない" ;;
        esac
        case "$output" in
            *"欠けているファイル"*) ok=0 detail="${detail}${detail:+ / }診断がファイルの欠落へ化けている" ;;
        esac
        [ "$ok" -eq 1 ] && collect_ok "$label" || collect_fail "$label" "$detail"
    fi
    chmod 755 "$dir"
    return 0
}

# 引数で渡した題材集合ディレクトリが検査対象になっている（本番の題材集合を見ていない）ことの検査。
# 同じサブコマンドが渡したディレクトリ次第で 0 と 1 に分かれることをもって切り替えの成立とみなす。
@test "面⑤: 題材集合ディレクトリの切り替えが効いている" {
    collect_init

    local label="10. 題材集合ディレクトリの切り替えが効いている（valid で 0・missing-id で 1。本番の題材集合を見ていない）"
    local valid_rc broken_rc
    sc validate "$CASES_DIR/valid"
    valid_rc=$status
    sc validate "$CASES_DIR/missing-id"
    broken_rc=$status
    if [ "$valid_rc" -eq 0 ] && [ "$broken_rc" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "valid=$valid_rc / missing-id=$broken_rc"
    fi

    collect_finish
}

# 実装済みでありながらアサーションを持たなかった検査を押さえる。
# 各 fixture は valid/ の複製から1箇所だけを壊したものである。
# 題材が1件も無いとき、診断を出さずに落ちてはならない。exit code だけでなく
# 診断文が出ることまで見ないと、無言で落ちる状態へ戻っても検査が通ってしまう。
@test "面⑥: validate 題材集合の整合違反" {
    collect_init

    sc validate "$CASES_DIR/duplicate-id"
    collect_run 1 "29. validate duplicate-id → exit 1、題材IDの重複を CASE-A1 として告げる" "重複" "CASE-A1"

    sc validate "$CASES_DIR/total-mismatch"
    collect_run 0 "30. validate total-mismatch → exit 0、合計期待値を持たない新スキーマでは旧 fixture の合計差を検査しない"

    sc validate "$CASES_DIR/unknown-partner"
    collect_run 1 "31. validate unknown-partner → exit 1、どの題材の対の相手IDが題材集合に無いのかを告げる" \
        "CASE-A1: 対の相手ID が題材集合に無い (CASE-ZZ)"

    sc validate "$CASES_DIR/asymmetric-pair"
    collect_run 1 "32. validate asymmetric-pair → exit 1、対の相手IDが相互参照になっていないことを告げる" "相互参照"

    sc validate "$CASES_DIR/invalid-origin"
    collect_run 1 "33. validate invalid-origin → exit 1、CASE-A2 の由来が語彙外であることを告げる" "CASE-A2" "語彙外"

    sc validate "$CASES_DIR/invalid-carrier"
    collect_run 1 "34. validate invalid-carrier → exit 1、CASE-A2 の規範の担い方が語彙外であることを告げる" "CASE-A2" "語彙外"

    sc validate "$CASES_DIR/no-header"
    collect_run 1 "35. validate no-header → exit 1、expectations.tsv のヘッダ行の欠落を告げる" "ヘッダ行"

    sc validate "$CASES_DIR/no-case-heading"
    collect_run 1 "37. validate no-case-heading → exit 1、題材が1件も無いことを診断として告げる（無言で落ちない）" \
        "題材が1件も無い"

    collect_finish
}

# 3層記述（メタ行・題材文）と雛形の異常。いずれも「題材文の無いプロンプトを生む」
# もしくは「原因を取り違えた診断で落ちる」経路であり、検査意図が同一である。
#
# 【fixture の担い分け】`has_meta_line` は先頭一致と改行つき一致を別分岐で持つ。
# メタ行が本文の1行目にあると先頭一致が先に当たって改行分岐が死ぬため、1つの fixture に
# 両方は担わせられない。38（meta-inside-body、メタ行は本文の途中）が改行分岐を、
# 38a（meta-inside-large-body、メタ行は本文の1行目）が先頭一致と SIGPIPE 経路を担う。
# fixture のメタ行の位置を動かすと、この担い分けが崩れる。
@test "面⑦: 3層記述・雛形の異常" {
    collect_init

    # メタ行を題材文ブロックの内側へ書いた場合、必須フィールド検査を通してはならない。
    # あわせて、メタ行が正しく外側にある valid では判定側へ渡るプロンプトにメタ行が
    # 現れないことを確かめ、メタ行と題材文の境界を両側から押さえる。
    local meta_label="38. validate meta-inside-body → exit 1、メタ行が題材文ブロックの内側にあることを CASE-A1 として告げる（あわせて valid の prompt にメタ行が漏れない）"
    local meta_ok=1 meta_detail="" needle meta_body=""
    sc validate "$CASES_DIR/meta-inside-body"
    [ "$status" -eq 1 ] || { meta_ok=0 meta_detail="validate の exit code 期待 1 / 実際 $status"; }
    # 「内側にある」ことの告知だけでは、メタ行の抽出範囲が題材文の内側まで伸びる退行を
    # 捕まえられない（本文からメタ行を拾えてしまうと未記入検査が素通りする）。
    # 未記入検査が本文を見ていないことまで、違反の中身と件数で押さえる。
    for needle in "メタ行が題材文ブロックの内側にある" "CASE-A1" \
        "判定対象の資産種別が未記入: CASE-A1" "規範の担い方が未記入: CASE-A1" "違反 3 件"; do
        case "$output" in
            *"$needle"*) ;;
            *) meta_ok=0 meta_detail="${meta_detail}${meta_detail:+ / }validate の出力に含まれない: $needle" ;;
        esac
    done
    sc_stdout prompt "$DOC" CASE-A1 "$CASES_DIR/valid"
    if [ "$status" -ne 0 ] || [ ! -f "$output" ]; then
        meta_ok=0
        meta_detail="${meta_detail}${meta_detail:+ / }prompt が組み立てに失敗した (rc=$status)"
    else
        meta_body="$(cat "$output")"
        rm -f "$output"
    fi
    case "$meta_body" in
        *"資産種別"*) meta_ok=0 meta_detail="${meta_detail}${meta_detail:+ / }valid の prompt へメタ行が漏れている: 資産種別" ;;
    esac
    [ "$meta_ok" -eq 1 ] && collect_ok "$meta_label" || collect_fail "$meta_label" "$meta_detail"

    # 題材文ブロックの内側にメタ行があり、かつ本文がパイプ長を超える場合。
    # 内側検査をパイプで書くと、grep が最初のマッチで閉じて書き手が SIGPIPE を受け、
    # 条件式の文脈では set -e が発火しないまま「違反なし」へ倒れて exit 0 で素通りする。
    sc validate "$CASES_DIR/meta-inside-large-body"
    collect_run 1 "38a. validate（メタ行が内側にあり題材文本文がパイプ長を超える）→ exit 1、内側にあることを告げる" \
        "メタ行が題材文ブロックの内側にある" "CASE-A1"

    # 題材文が空の題材を、validate も prompt も通してはならない。
    sc validate "$CASES_DIR/empty-body"
    collect_run 1 "38b. validate（題材文が空）→ exit 1、3層のうち題材文が欠けていることを告げる" \
        "3層のうち題材文が欠けている" "CASE-A1"

    sc prompt "$DOC" CASE-A1 "$CASES_DIR/empty-body"
    collect_run 1 "38c. prompt（題材文が空）→ exit 1、題材文が空であることを告げる" "題材文が空である"

    # 差し込み記号を書き落とした雛形は、題材文の無いプロンプトを exit 0 で生む。
    # 検査を validate だけに置くと、成果物を生む側（prompt は validate を呼ばない）が
    # 塞がらないため、同じ雛形を両方の経路へ通す。
    sc validate "$CASES_DIR/template-missing-marker"
    collect_run 1 "38d. validate（雛形が {{題材文}} を欠く）→ exit 1、欠けている差し込み記号を名指しする" \
        "prompt-template.md に差し込み記号が無い: {{題材文}}"

    sc prompt "$DOC" CASE-A1 "$CASES_DIR/template-missing-marker"
    collect_run 1 "38e. prompt（雛形が {{題材文}} を欠く）→ exit 1、欠けている差し込み記号を名指しする（題材文の無いプロンプトを生まない）" \
        "prompt-template.md に差し込み記号が無い" "{{題材文}}"

    # 読めないファイルは「中身が無い」と区別できない形へ化ける。雛形が読めない場合、
    # 記号の走査（grep）が非0を返すため、記号が3つとも欠けていると報告されてしまう。
    # 原因を名指しできる位置で落とすことを、診断の中身で押さえる。
    local unread_dir="$BATS_TEST_TMPDIR/unreadable-template"
    local unread_label="38f. prompt（雛形を読めない）→ exit 2、読めないことを名指しする（記号の欠落へ化けない）"
    copy_valid_case_dir "$unread_dir"
    chmod 000 "$unread_dir/prompt-template.md"
    if [ -r "$unread_dir/prompt-template.md" ]; then
        # root 実行等で読めてしまう環境では成立しない検査なので、その旨を告知して飛ばす
        collect_skipped "$unread_label" "chmod 000 でも読める環境のため未実行"
    else
        sc prompt "$DOC" CASE-A1 "$unread_dir"
        local unread_ok=1 unread_detail=""
        [ "$status" -eq 2 ] || { unread_ok=0 unread_detail="exit code 期待 2 / 実際 $status"; }
        case "$output" in
            *"読めないファイル: prompt-template.md"*) ;;
            *) unread_ok=0 unread_detail="${unread_detail}${unread_detail:+ / }読めないことを名指ししていない" ;;
        esac
        case "$output" in
            *"差し込み記号が無い"*) unread_ok=0 unread_detail="${unread_detail}${unread_detail:+ / }診断が記号の欠落へ化けている" ;;
        esac
        [ "$unread_ok" -eq 1 ] && collect_ok "$unread_label" || collect_fail "$unread_label" "$unread_detail"
    fi
    chmod 644 "$unread_dir/prompt-template.md"

    collect_finish
}

# ---------------------------------------------------------------- prompt 系

@test "面⑧: prompt 題材文の差し込み" {
    collect_init

    local label11="11. prompt valid CASE-A1 → exit 0、標準出力は実在するファイルのパス1行"
    local prompt_path prompt_rc prompt_lines prompt_body=""
    sc_stdout prompt "$DOC" CASE-A1 "$CASES_DIR/valid"
    prompt_path="$output"
    prompt_rc=$status
    prompt_lines="$(printf '%s\n' "$prompt_path" | wc -l | tr -d ' ')"
    if [ "$prompt_rc" -eq 0 ] && [ "$prompt_lines" -eq 1 ] && [ -f "$prompt_path" ]; then
        collect_ok "$label11"
    else
        collect_fail "$label11" "rc=$prompt_rc / 行数=$prompt_lines / 出力=$prompt_path"
    fi

    [ -f "$prompt_path" ] && prompt_body="$(cat "$prompt_path")"

    collect_out "$prompt_body" "12. 組み立てたプロンプトに CASE-A1 の題材文が含まれる" "コミットを止める"

    # 期待帰結層（expectations.tsv 由来の文字列）と他題材がプロンプトへ漏れていないこと。
    local leak_label="13. 組み立てたプロンプトに期待帰結層・他題材に由来する文字列が含まれない"
    local leak_ok=1 leak_detail="" needle
    for needle in "期待_" "改訂前から在る" "導出すべきもの" "NONE" "fixture（正常系）" "散文で述べているだけ"; do
        case "$prompt_body" in
            *"$needle"*) leak_ok=0 leak_detail="${leak_detail}${leak_detail:+ / }漏れている: $needle" ;;
        esac
    done
    [ "$leak_ok" -eq 1 ] && collect_ok "$leak_label" || collect_fail "$leak_label" "$leak_detail"

    [ -n "$prompt_path" ] && [ -f "$prompt_path" ] && rm -f "$prompt_path"

    collect_finish
}

# 題材IDの存在検査を正規表現一致で書くと、`CASE-A.` のような入力が既知の題材へ当たって
# 存在検査を通過する。exit code だけでは後段の「題材文が空である」と区別できないため、
# 診断が「題材ID が題材集合に無い」であることまで押さえる。
@test "面⑨: prompt 題材IDの異常" {
    collect_init

    sc prompt "$DOC" CASE-ZZ "$CASES_DIR/valid"
    collect_run 1 "14. prompt（題材集合に無い題材ID）→ exit 1、既知の題材IDを列挙する" "CASE-A1"

    sc prompt "$DOC" 'CASE-A.' "$CASES_DIR/valid"
    collect_run 1 "14a. prompt（題材IDに正規表現メタ文字を含む）→ exit 1、題材IDが題材集合に無いことを告げる（別の診断へ化けない）" \
        "題材ID が題材集合に無い: CASE-A."

    collect_finish
}

@test "面⑩: prompt ファイル・引数の異常" {
    collect_init

    sc prompt "$MISSING_DOC" CASE-A1 "$CASES_DIR/valid"
    collect_run 2 "15. prompt（存在しない対象文書）→ exit 2"

    sc prompt "$DOC" CASE-A1
    collect_run 2 "16. prompt（題材集合ディレクトリの省略）→ exit 2、使い方を示す" "使い方"

    sc prompt "$DOC" CASE-A1 "$CASES_DIR/no-template"
    collect_run 2 "17. prompt no-template → exit 2、prompt-template.md を欠けているファイルとして告げる" "prompt-template.md"

    collect_finish
}

# ---------------------------------------------------------------- report 系

# 項目1〜4 以外の出力層（カバレッジ件数・合計列・行き先列・差の総数）も押さえる。
# 項目別の一致率だけを見ていると、これらを壊しても検査が通ってしまう。
@test "面⑪: report 正常系の出力内容" {
    collect_init

    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local report_output="$output"
    collect_run 0 "18. report valid-judgments.tsv valid → exit 0"

    collect_out "$report_output" "19. report 出力がセル単位の試行間一致件数を含む" \
        "試行 1 と 試行 2: 一致 7 / 8 セル (87.5%)"

    collect_out "$report_output" "20. report 出力が項目別一致率を4項目分含む" \
        "項目1: 一致 2 / 2 (100.0%)" \
        "項目2: 一致 2 / 2 (100.0%)" \
        "項目3: 一致 1 / 2 (50.0%)" \
        "項目4: 一致 2 / 2 (100.0%)"

    collect_out "$report_output" "21. report 出力が各項目の1点率（周辺分布）を試行ごとに含む" \
        "== 各項目の1点率（周辺分布。試行ごと） ==" \
        "試行 1:  項目1 50.0% (1/2)  項目2 50.0% (1/2)  項目3 50.0% (1/2)  項目4 50.0% (1/2)" \
        "試行 2:  項目1 50.0% (1/2)  項目2 50.0% (1/2)  項目3 0.0% (0/2)  項目4 50.0% (1/2)"

    collect_out "$report_output" "22. report 出力が期待帰結との差として CASE-A2 の項目3 の差を含む" \
        "CASE-A2 試行2 項目3: 期待 1 / 判定 0"

    collect_out "$report_output" "22a. report 出力がカバレッジ件数行を含む" \
        "題材 2 件中 2 件を記録が覆う"

    collect_out "$report_output" "22b. report 出力が合計列・行き先列の試行間一致率を含む" \
        "合計: 一致 1 / 2 (50.0%)" \
        "行き先: 一致 2 / 2 (100.0%)"

    collect_out "$report_output" "22c. report 出力が期待帰結との差として項目差と差の総数を含む" \
        "差 1 件"

    collect_finish
}

@test "面⑪a: report の合計一致は項目1〜4から導出する" {
    collect_init

    local judgments="$BATS_TEST_TMPDIR/derived-total-judgments.tsv"
    awk -F '\t' -v OFS='\t' '
        /^#/ { print; next }
        $1 == "題材ID" { for (i = 1; i <= NF; i++) if (i != 7) printf "%s%s", $i, (i == NF ? ORS : OFS); next }
        {
            for (i = 1; i <= NF; i++) if (i != 7) {
                value = $i
                if ($1 == "CASE-A2" && $2 == "2" && i == 3) value = 0
                printf "%s%s", value, (i == NF ? ORS : OFS)
            }
        }
    ' "$JUDGMENTS_DIR/valid-judgments.tsv" > "$judgments"

    sc report "$judgments" "$CASES_DIR/valid"
    collect_run 0 "22d. report（合計列を除き項目値を変更）→ 項目1〜4の和から合計一致を算出する" \
        "合計: 一致 1 / 2 (50.0%)"

    collect_finish
}

@test "面⑫: report 記録の異常" {
    collect_init

    sc report "$JUDGMENTS_DIR/unknown-id-judgments.tsv" "$CASES_DIR/valid"
    collect_run 1 "23. report unknown-id-judgments.tsv → exit 1、CASE-ZZ を列挙する" "CASE-ZZ"

    sc report "$JUDGMENTS_DIR/missing-case-judgments.tsv" "$CASES_DIR/valid"
    collect_run 1 "24. report missing-case-judgments.tsv → exit 1、未カバー題材 CASE-A2 を列挙する" "CASE-A2" "未カバー"

    sc report "$JUDGMENTS_DIR/duplicate-judgments.tsv" "$CASES_DIR/valid"
    collect_run 1 "36. report duplicate-judgments.tsv → exit 1、CASE-A1 の重複した行を告げる" "重複" "CASE-A1"

    # commit 列にプレースホルダが残ったまま提出された記録を素通りさせない。
    # 題材集合commit列を持たない記録（他の judgments fixture は13列）は検査対象外であることも同時に押さえる。
    sc report "$JUDGMENTS_DIR/unresolved-commit-judgments.tsv" "$CASES_DIR/valid"
    collect_run 1 "36a. report（commit 列にプレースホルダが残る記録）→ exit 1、13列目・14列目それぞれを題材・試行・列名で名指しする" \
        "CASE-A1 試行1 題材集合commit が短縮ハッシュでない: 未コミット" \
        "CASE-A2 試行1 対象文書commit が短縮ハッシュでない: 未コミット" \
        "未確定 2 件"

    collect_finish
}

@test "面⑬: report 引数の異常" {
    collect_init

    sc report "$JUDGMENTS_DIR/この判定記録は存在しない.tsv" "$CASES_DIR/valid"
    collect_run 2 "25. report（存在しない判定記録TSV）→ exit 2、判定記録TSV が存在しないことを理由として告げる" \
        "判定記録TSV が存在しない"

    sc report "$JUDGMENTS_DIR/valid-judgments.tsv"
    collect_run 2 "26. report（題材集合ディレクトリの省略）→ exit 2、引数の個数が合わないことを理由として告げる" \
        "report は引数を2つ取る"

    collect_finish
}

# 試行番号は連想配列の添字（＝文字列）として集まるため、素朴に `<` で比べると
# "10" < "2" となり、試行が10以上あると比較対象が試行1と試行10 に化ける。
@test "面⑭: report 試行番号の数値順" {
    collect_init

    sc report "$JUDGMENTS_DIR/two-digit-trial-judgments.tsv" "$CASES_DIR/valid"
    collect_run 0 "45. report（試行番号が2桁を含む）→ 試行番号を数値順に並べ、試行1と試行2 を比較する" \
        "試行が 3 つあるため、試行 1 と 試行 2 のみを比較した" \
        "試行 1 と 試行 2: 一致 7 / 8 セル (87.5%)"

    collect_finish
}

# ---------------------------------------------------------------- サブコマンド

@test "面⑮: サブコマンドの異常" {
    collect_init

    sc
    collect_run 2 "27. サブコマンド無し → exit 2、使い方を示す" "使い方"

    sc 存在しないサブコマンド
    collect_run 2 "28. 不明なサブコマンド → exit 2、受け取ったサブコマンド名を添えて理由を告げる" \
        "サブコマンドが不明: 存在しないサブコマンド"

    collect_finish
}

# 実データを通る唯一の常設一致ゲート。題材本文は読まず、版ずれの門番と
# 据え置き6組の免除記録だけを検査する。
@test "面⑯: 実データの crosscheck 常設ゲート" {
    local doc_commit
    # 台帳が記録している対象文書の版を使う。現行版を渡すと歴史的42件を
    # 全てスキップし、常設ゲートが何も照合しないためである。
    doc_commit="$(awk -F '\t' '!/^#/ && $1 != "題材ID" { print $13; exit }' \
        "$REPO_ROOT/docs/development/adr-scoping-cases/runs/2026-07-29-judgments.tsv")"
    run bash "$SUT" crosscheck \
        "$REPO_ROOT/docs/development/adr-scoping-cases/runs/2026-07-29-judgments.tsv" \
        "$REPO_ROOT/docs/development/adr-scoping-cases/runs/2026-07-29-returns" \
        --thresholds "$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json" \
        --doc-commit "$doc_commit" \
        --allow-missing CASE-01:1 --allow-missing CASE-01:2 \
        --allow-missing CASE-02:1 --allow-missing CASE-02:2 \
        --allow-missing CASE-17:1 --allow-missing CASE-17:2
    [ "$status" -eq 0 ]
    [[ "$output" == *"照合件数: 42"* ]]
    [[ "$output" == *"スキップ件数: 0"* ]]
    run grep -F "CASE-01:1" "$REPO_ROOT/docs/development/adr-scoping-cases/README.md"
    [ "$status" -eq 0 ]

    run bash "$SUT" crosscheck \
        "$REPO_ROOT/docs/development/adr-scoping-cases/runs/2026-07-29-judgments.tsv" \
        "$REPO_ROOT/docs/development/adr-scoping-cases/runs/2026-07-29-returns" \
        --thresholds "$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json" \
        --doc-commit deadbee
    [ "$status" -ne 0 ]
}

@test "面⑰: derive は実測事実と閾値設定から算出する" {
    local json="$REPO_ROOT/scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json"
    local thresholds="$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json"
    run bash "$SUT" derive "$json" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"項目1: 1"* ]]
    [[ "$output" == *"合計: 2"* ]]

    local altered="$BATS_TEST_TMPDIR/altered-thresholds.json"
    sed 's/"item1_file_count": 3/"item1_file_count": 4/' "$thresholds" > "$altered"
    run bash "$SUT" derive "$json" --thresholds "$altered" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"項目1: 0"* ]]

    local altered_json="$BATS_TEST_TMPDIR/altered-return.json"
    jq '."項目1_追跡下ファイル" = ["a", "b"] | ."項目1_追跡下ファイル数" = 2' "$json" > "$altered_json"
    run bash "$SUT" derive "$altered_json" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"項目1: 0"* ]]

    local warning="$BATS_TEST_TMPDIR/warning-return.json"
    jq '."項目4_阻止状態" = "警告どまり"' "$json" > "$warning"
    run bash "$SUT" derive "$warning" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"項目4: 1"* ]]

    local condition1="$BATS_TEST_TMPDIR/condition1-return.json"
    jq '."項目3_採用理由確認可能" = true | ."項目3_条件1" = true' "$json" > "$condition1"
    run bash "$SUT" derive "$condition1" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"項目3: 1"* ]]

    local no_alternative="$BATS_TEST_TMPDIR/no-alternative-return.json"
    jq '."必要条件_成立" = false' "$json" > "$no_alternative"
    run bash "$SUT" derive "$no_alternative" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -eq 0 ]
    [[ "$output" == *"必要条件: 不成立"* ]]
}

@test "面⑱: derive は型違反と閾値欠落を fail-closed で拒否する" {
    local json="$REPO_ROOT/scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json"
    local thresholds="$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json"
    local invalid="$BATS_TEST_TMPDIR/invalid-return.json"
    jq '."項目1_追跡下ファイル数" = "3"' "$json" > "$invalid"
    run bash "$SUT" derive "$invalid" --thresholds "$thresholds" --doc-commit 0000000
    [ "$status" -ne 0 ]
    [[ "$output" == *"型または件数"* ]]

    run bash "$SUT" derive "$json" --doc-commit 0000000
    [ "$status" -eq 2 ]

    local decimal="$BATS_TEST_TMPDIR/decimal-thresholds.json"
    sed 's/"adr_score_boundary": 3/"adr_score_boundary": 2.5/' "$thresholds" > "$decimal"
    run bash "$SUT" derive "$json" --thresholds "$decimal" --doc-commit 0000000
    [ "$status" -ne 0 ]
}

@test "面⑲: crosscheck は台帳とJSONの改変を検出する" {
    local tsv="$BATS_TEST_TMPDIR/one-judgment.tsv"
    awk -F '\t' 'BEGIN { OFS="\t" } /^#/ || $1 == "題材ID" { print; next } $1 == "CASE-A1" { $3=1; $6=1; print }' \
        "$REPO_ROOT/scripts/fixtures/adr-scoping-cases/judgments/valid-judgments.tsv" > "$tsv"
    local thresholds="$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json"
    local returns="$REPO_ROOT/scripts/fixtures/adr-scoping-cases/returns"
    run bash "$SUT" crosscheck "$tsv" "$returns" --thresholds "$thresholds" --doc-commit 0000000 --allow-missing CASE-A1:2
    [ "$status" -eq 0 ]

    local changed="$BATS_TEST_TMPDIR/changed-judgment.tsv"
    awk -F '\t' 'BEGIN { OFS="\t" } { if ($1 == "CASE-A1" && $2 == "1") $3=0; print }' "$tsv" > "$changed"
    run bash "$SUT" crosscheck "$changed" "$returns" --thresholds "$thresholds" --doc-commit 0000000 --allow-missing CASE-A1:2
    [ "$status" -ne 0 ]
    [[ "$output" == *"不一致"* ]]
}

@test "面⑳: 契約と閾値の所在宣言が文書化されている" {
    local contract="$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-judgment-contract.md"
    local scoping="$REPO_ROOT/plugins/adr/skills/manage-adr/references/adr-scoping.md"
    local skill="$REPO_ROOT/plugins/adr/skills/manage-adr/SKILL.md"
    run grep -F "adr-scoring-thresholds.json" "$contract"
    [ "$status" -eq 0 ]
    run grep -F "adr-scoring-thresholds.json" "$scoping"
    [ "$status" -eq 0 ]
    run grep -F "adr-judgment-contract.md" "$scoping"
    [ "$status" -eq 0 ]
    run grep -F "## 直列化形式" "$contract"
    [ "$status" -eq 0 ]
    run grep -F "## 判定ごとの必須ルール" "$contract"
    [ "$status" -eq 0 ]
    run grep -F "3点以上" "$scoping"
    [ "$status" -ne 0 ]
    run grep -F "2点以下" "$scoping"
    [ "$status" -ne 0 ]
    run grep -F "adr-scoring-thresholds.json" "$skill"
    [ "$status" -eq 0 ]
}
