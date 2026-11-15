#!/usr/bin/env bats
# 古い bash の実体で lint-adr.sh を確かめる検査器（scripts/check-lint-adr-old-bash.sh）のテスト。
#
# 検査器は、CI で bash 3.2 のコンテナを起動して lint を走らせ、版の判定が原因を示して exit 2 で
# 止めることを確かめる。本テストは、その検査器が期待と違う結果を見逃さないことを固定する。
# 本物の bash 3.2 はここでは起動しない。古い bash の代わりに、引数に応じて振る舞いを変える
# スタブを渡す。
#
# 正例は、BASH_VERSION を 3.2 に差し替えたシェルで本物の lint-adr.sh を読み込むスタブで作る。
# 負例は次のとおりである。
#   - 版の判定が働かない（4.2 以上として通る）
#   - exit 2 だが、案内より先に解釈の誤りが出る
#   - 案内は出るが exit 2 ではない
#   - lint の結果は期待どおりだが、起動したシェルが 4.2 未満の bash でない（版が新しい・空・数でない）
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。

load 'helpers/common'

SUT="$REPO_ROOT/scripts/check-lint-adr-old-bash.sh"
CORPORA=()
PRECONDITION_PATHS=("$PLUGIN_ROOT/scripts/lint-adr.sh")

setup_file() {
    common_setup_file
}

# lint を、BASH_VERSION を差し替えて読み込むスタブを作る。`-c` で呼ばれたら版を出す。
make_sourcing_stub() {
    local path="$1" version="$2"
    cat >"$path" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-c" ]; then echo "$version"; exit 0; fi
BASH_VERSION="$version"
. "\$1" "\$2"
EOF
    chmod +x "$path"
}

# 決まった出力と終了コードを返すスタブを作る。第4引数は `-c` で出す版（省くと 3.2）。
# `-c` では、イメージの取得の進み具合に当たる行を標準エラーへ出してから版を出す。
make_fixed_stub() {
    local path="$1" rc="$2" out="$3" version="${4-3.2.57(1)-release}"
    cat >"$path" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-c" ]; then echo "Status: Downloaded newer image for bash:3.2.57" >&2; echo "$version"; exit 0; fi
printf '%s\n' "$out"
exit $rc
EOF
    chmod +x "$path"
}

run_checker() {
    run bash -c 'cd "$1" && shift && bash "$@"' _ "$REPO_ROOT" "$SUT" "$@"
}

@test "前提: 被テスト検査器と lint-adr.sh が存在する" {
    assert_preconditions_met
}

@test "面①: 版の判定が案内を最初の行に出して exit 2 で止めれば、合格とする" {
    collect_init

    local stub="$BATS_TEST_TMPDIR/bash32"
    make_sourcing_stub "$stub" "3.2.57(1)-release"
    run_checker "$stub"
    collect_rc 0 "bash 3.2 として読み込んだ本物の lint で合格する"
    collect_contains "$output" "起動した bash の版: 3.2.57(1)-release" "実測した版がログに残る"
    collect_contains "$output" "lint-adr.sh の exit code: 2" "lint の終了コードがログに残る"

    collect_finish
}

@test "面②: 期待と違う結果を見逃さない" {
    collect_init

    local stub="$BATS_TEST_TMPDIR/bash5"
    make_sourcing_stub "$stub" "5.2.21(1)-release"
    run_checker "$stub"
    collect_rc 1 "版の判定が働かず lint が先へ進めば、不合格とする"

    stub="$BATS_TEST_TMPDIR/noisy"
    make_fixed_stub "$stub" 2 "bash: line 1: syntax error
エラー: lint-adr.sh は bash 4.2 以上を必要とします（実行中の bash: 3.2.57(1)-release）。"
    run_checker "$stub"
    collect_rc 1 "exit 2 でも、案内より先に解釈の誤りが出れば、不合格とする"
    collect_contains "$output" "出力の最初の行が" "最初の行でないことが理由として示される"

    stub="$BATS_TEST_TMPDIR/wrong-rc"
    make_fixed_stub "$stub" 1 "エラー: lint-adr.sh は bash 4.2 以上を必要とします（実行中の bash: 3.2.57(1)-release）。"
    run_checker "$stub"
    collect_rc 1 "案内が出ても exit 2 でなければ、不合格とする"
    collect_contains "$output" "exit 2 を期待したが 1 だった" "終了コードの食い違いが理由として示される"

    run_checker
    collect_rc 2 "古い bash を起動するコマンドを渡さなければ、引数の誤りとする"

    collect_finish
}

@test "面③: 起動したシェルが 4.2 未満の bash であることを確かめる" {
    collect_init

    local msg="エラー: lint-adr.sh は bash 4.2 以上を必要とします（実行中の bash: 3.2.57(1)-release）。"
    local stub="$BATS_TEST_TMPDIR/stderr-noise"
    make_fixed_stub "$stub" 2 "$msg"
    run_checker "$stub"
    collect_rc 0 "取得の進み具合が標準エラーに出ても、標準出力の版で合格する"
    collect_contains "$output" "起動した bash の版: 3.2.57(1)-release" "版の行に取得の進み具合が混ざらない"

    stub="$BATS_TEST_TMPDIR/modern"
    make_fixed_stub "$stub" 2 "$msg" "5.2.21(1)-release"
    run_checker "$stub"
    collect_rc 1 "lint の結果が期待どおりでも、起動した bash が 4.2 以上なら不合格とする"
    collect_contains "$output" "4.2 以上（5.2.21(1)-release）" "版が新しいことが理由として示される"

    stub="$BATS_TEST_TMPDIR/bash42"
    make_fixed_stub "$stub" 2 "$msg" "4.2.53(1)-release"
    run_checker "$stub"
    collect_rc 1 "境界の 4.2 は古い bash に数えない"

    stub="$BATS_TEST_TMPDIR/bash41"
    make_fixed_stub "$stub" 2 "$msg" "4.1.17(1)-release"
    run_checker "$stub"
    collect_rc 0 "境界の直前の 4.1 は古い bash に数える"

    stub="$BATS_TEST_TMPDIR/empty"
    make_fixed_stub "$stub" 2 "$msg" ""
    run_checker "$stub"
    collect_rc 1 "版が空（bash でないシェル）なら不合格とする"
    collect_contains "$output" "bash の版として読めない" "版を読めないことが理由として示される"

    stub="$BATS_TEST_TMPDIR/garbage"
    make_fixed_stub "$stub" 2 "$msg" "unknown"
    run_checker "$stub"
    collect_rc 1 "版が数で始まらなければ不合格とする"

    collect_finish
}
