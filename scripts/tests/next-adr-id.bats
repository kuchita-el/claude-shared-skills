#!/usr/bin/env bats
# ADR 識別子発番器（plugins/adr/scripts/next-adr-id.sh）のテスト。
#
# 発番結果を、一時ディレクトリへ組み立てた corpus に対して検証する。
# 時刻部は ADR_TIMESTAMP で固定し、実時刻に依存しない検査にする。
#
# 「同一時刻部の内側だけを見て最大 + 1 を取る（配置ディレクトリ全体・同日全体は見ない）」という
# 発番の中核は、2026-07-26 に2本の PR が当時の日単位手順をそれぞれ正しく実行して同一識別子を
# 発番した実測を受けたものである。発番を機械実行へ委ねたのは手順の解釈差を入れないためであり、
# 本テストはその中核が実行のたびに再現されることを固定する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# corpus はケースごとに一時ディレクトリへ組み立てるため共有できない。よって共有 setup_file の
# CORPORA は空にし、検査器の起動はケース内で `run` により直接行う（helpers/common.bash の
# 「検査器の起動の型」に従う）。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/next-adr-id.sh"
CORPORA=()

TS="203104091530"

setup_file() {
    common_setup_file
}

# 一時ディレクトリを作り、引数で渡した ADR ファイル名を空ファイルとして配置する
make_corpus() {
    local dir name
    dir="$(mktemp -d "$BATS_TEST_TMPDIR/corpus.XXXXXX")"
    for name in "$@"; do
        : >"$dir/$name"
    done
    printf '%s' "$dir"
}

# 発番を実行し「識別子:exit code」形式で返す。
# stderr は判定に含めないため --separate-stderr で分離する（旧ランナーの 2>/dev/null 相当）。
next_id() {
    local dir="$1"
    # `-` を使う（`:-` だと空文字の引数が既定値へ畳まれ、空文字ケースを検査できない）
    local timestamp="${2-$TS}"
    run --separate-stderr env ADR_TIMESTAMP="$timestamp" bash "$SUT" "$dir"
    printf '%s:%s' "$output" "$status"
}

# 前提不成立は setup_file では失敗させず、この1ケースの失敗として報告する。
# ファイル全体が `setup_file failed` の1件へ潰れると報告総数が変動するため。
@test "前提: 被テスト検査器が存在する" {
    assert_preconditions_met
}

@test "面①: 連番の算出" {
    collect_init

    local dir
    dir="$(make_corpus)"
    collect_equals "$(next_id "$dir")" "ADR-$TS-01:0" \
        "空ディレクトリでは 01 を発番する"

    # corpus の slug は実運用と同じ複数トークン（ハイフン区切り）にする。単一トークンだけだと
    # 連番部の切り出しが最長一致（`${seq%%-*}`）か最短一致（`${seq%-*}`）かを区別できず、
    # 既存 ADR を見落として重複を発番する変異がテストを素通りする。
    dir="$(make_corpus "ADR-$TS-01-cache-layer-replacement.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-02:0" \
        "同一時刻部に 01 があれば 02 を発番する（複数トークン slug）"

    dir="$(make_corpus "ADR-$TS-09-adr-id-timestamp-numbering.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-10:0" \
        "09 の次は 10（10進解釈で8進エラーにならない）"

    dir="$(make_corpus "ADR-$TS-01-state-model-and-drift-lint.md" "ADR-$TS-03-edit-mechanism.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-04:0" \
        "欠番があっても最大番号 + 1 を発番する"

    collect_finish
}

@test "面②: 時刻部による分離（並行ブランチ衝突の防止）" {
    collect_init

    local dir
    dir="$(make_corpus "ADR-203104091529-01-earlier.md" "ADR-203104091531-02-later.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-01:0" \
        "同日でも時刻部が異なる ADR は連番に影響しない"

    dir="$(make_corpus "ADR-20310409-01-legacy.md" "ADR-20310409-07-legacy.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-01:0" \
        "時刻部を持たない旧形式 ADR は連番に影響しない"

    dir="$(make_corpus "ADR-$TS-x1-broken.md" "ADR-$TS-1-single-digit.md")"
    collect_equals "$(next_id "$dir")" "ADR-$TS-01:0" \
        "連番部が2桁数字でないファイルは読み飛ばす"

    collect_finish
}

@test "面③: 対象ディレクトリ不在" {
    collect_init
    collect_equals "$(next_id "/nonexistent/adr-dir-for-test")" ":2" \
        "対象ディレクトリ不在は exit 2"
    collect_finish
}

@test "面④: 連番の上限" {
    collect_init
    local dir
    dir="$(make_corpus "ADR-$TS-99-lifecycle-tooling-delegation.md")"
    collect_equals "$(next_id "$dir")" ":1" \
        "同一時刻部の既存の最大連番が 99 なら exit 1"
    collect_finish
}

# 時刻部の検査。桁数だけでなく暦としての妥当性も見る（遡及発番やテストで format 文字列を
# 打ち間違えても12桁なら通ってしまうと、誤った識別子を無警告で量産できるため）。
@test "面⑤: 時刻部の妥当性" {
    collect_init

    local dir
    dir="$(make_corpus)"
    collect_equals "$(next_id "$dir" "20310409")" ":1" \
        "時刻部が12桁でなければ exit 1"
    collect_equals "$(next_id "$dir" "999999999999")" ":1" \
        "12桁でも暦として不正なら exit 1"
    collect_equals "$(next_id "$dir" "203113451599")" ":1" \
        "13月45日15時99分は exit 1"
    collect_equals "$(next_id "$dir" "")" ":1" \
        "空文字は現在時刻へ畳まず exit 1"

    collect_finish
}

# 時刻部の値そのものを、テスト側で取ったローカル時刻の分と突き合わせる。桁数だけを見ると
# UTC 化（date -u）も秒粒度化（%M→%S）も素通りするため、決定が定める「ローカル時刻」
# 「分粒度」の2性質を値の一致で押さえる。実行が分をまたぐ場合に備え、呼び出し前後の
# いずれかに一致すれば合格とする。
@test "面⑥: ADR_TIMESTAMP 未設定時の実時刻フォールバック" {
    collect_init

    local dir before after label
    label="ADR_TIMESTAMP 未設定ならローカル時刻の分と一致する時刻部を発番する"
    dir="$(make_corpus)"
    before="$(date +%Y%m%d%H%M)"
    run --separate-stderr bash "$SUT" "$dir"
    after="$(date +%Y%m%d%H%M)"

    if [ "$status" -eq 0 ] && { [ "$output" = "ADR-$before-01" ] || [ "$output" = "ADR-$after-01" ]; }; then
        collect_ok "$label"
    else
        collect_fail "$label" "got \"$output\" (exit $status, local $before)"
    fi

    collect_finish
}
