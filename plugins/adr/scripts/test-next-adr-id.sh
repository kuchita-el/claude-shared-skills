#!/usr/bin/env bash
# ADR 識別子発番器のテストランナー
#
# next-adr-id.sh の発番結果を、一時ディレクトリへ組み立てた corpus に対して検証する。
# 時刻部は ADR_TIMESTAMP で固定し、実時刻に依存しない検査にする。
#
# 使い方:
#   bash plugins/adr/scripts/test-next-adr-id.sh
#
# exit code:
#   0: 全アサーションパス
#   1: いずれか失敗
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEXT_ADR_ID="$PLUGIN_ROOT/scripts/next-adr-id.sh"

TS="203104091530"

passed=0
failed=0
total=0

# 実測値が期待値と一致することをアサート
assert_equals() {
    local actual="$1" expected="$2" label="$3"
    total=$((total + 1))
    if [ "$actual" = "$expected" ]; then
        printf '[PASS] %s\n' "$label"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: expected "%s" but got "%s"\n' "$label" "$expected" "$actual"
        failed=$((failed + 1))
    fi
}

# 一時ディレクトリを作り、引数で渡した ADR ファイル名を空ファイルとして配置する
make_corpus() {
    local dir
    dir="$(mktemp -d)"
    local name
    for name in "$@"; do
        : >"$dir/$name"
    done
    printf '%s' "$dir"
}

# 発番を実行し「識別子:exit code」形式で返す（set -e 下でも exit code を握りつぶさない）
run_next() {
    local dir="$1"
    local timestamp="${2:-$TS}"
    local output rc
    set +e
    output=$(ADR_TIMESTAMP="$timestamp" bash "$NEXT_ADR_ID" "$dir" 2>/dev/null)
    rc=$?
    set -e
    printf '%s:%s' "$output" "$rc"
}

if [ ! -f "$NEXT_ADR_ID" ]; then
    printf '[FAIL] next-adr-id.sh not found: %s\n' "$NEXT_ADR_ID"
    exit 1
fi

# ==== 発番の基本 ====

run_empty_dir() {
    local dir
    dir="$(make_corpus)"
    assert_equals "$(run_next "$dir")" "ADR-$TS-01:0" "空ディレクトリでは 01 を発番する"
    rm -rf "$dir"
}

run_same_minute_increment() {
    local dir
    dir="$(make_corpus "ADR-$TS-01-first.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-02:0" "同一時刻部に 01 があれば 02 を発番する"
    rm -rf "$dir"
}

run_same_minute_zero_padding() {
    local dir
    dir="$(make_corpus "ADR-$TS-09-ninth.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-10:0" "09 の次は 10（10進解釈で8進エラーにならない）"
    rm -rf "$dir"
}

run_same_minute_gap() {
    local dir
    dir="$(make_corpus "ADR-$TS-01-a.md" "ADR-$TS-03-c.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-04:0" "欠番があっても最大番号 + 1 を発番する"
    rm -rf "$dir"
}

# ==== 時刻部による分離（並行ブランチ衝突の防止） ====

run_other_minute_same_day_ignored() {
    local dir
    dir="$(make_corpus "ADR-203104091529-01-earlier.md" "ADR-203104091531-02-later.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-01:0" "同日でも時刻部が異なる ADR は連番に影響しない"
    rm -rf "$dir"
}

run_legacy_format_ignored() {
    local dir
    dir="$(make_corpus "ADR-20310409-01-legacy.md" "ADR-20310409-07-legacy.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-01:0" "時刻部を持たない旧形式 ADR は連番に影響しない"
    rm -rf "$dir"
}

run_malformed_sequence_ignored() {
    local dir
    dir="$(make_corpus "ADR-$TS-x1-broken.md" "ADR-$TS-1-single-digit.md")"
    assert_equals "$(run_next "$dir")" "ADR-$TS-01:0" "連番部が2桁数字でないファイルは読み飛ばす"
    rm -rf "$dir"
}

# ==== 異常系 ====

run_missing_dir() {
    assert_equals "$(run_next "/nonexistent/adr-dir-for-test")" ":2" "対象ディレクトリ不在は exit 2"
}

run_upper_bound() {
    local dir
    dir="$(make_corpus "ADR-$TS-99-last.md")"
    assert_equals "$(run_next "$dir")" ":1" "同一時刻部が 99 件に達していれば exit 1"
    rm -rf "$dir"
}

run_invalid_timestamp() {
    local dir
    dir="$(make_corpus)"
    assert_equals "$(run_next "$dir" "20310409")" ":1" "時刻部が12桁でなければ exit 1"
    rm -rf "$dir"
}

# ==== 実時刻での発番（ADR_TIMESTAMP 未設定時のフォールバック） ====

run_local_clock_format() {
    local dir output rc
    dir="$(make_corpus)"
    set +e
    output=$(bash "$NEXT_ADR_ID" "$dir" 2>/dev/null)
    rc=$?
    set -e
    total=$((total + 1))
    if [ "$rc" -eq 0 ] && [[ "$output" =~ ^ADR-[0-9]{12}-01$ ]]; then
        printf '[PASS] %s\n' "ADR_TIMESTAMP 未設定ならローカル時刻から12桁の時刻部を発番する"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: got "%s" (exit %s)\n' "ADR_TIMESTAMP 未設定ならローカル時刻から12桁の時刻部を発番する" "$output" "$rc"
        failed=$((failed + 1))
    fi
    rm -rf "$dir"
}

run_empty_dir
run_same_minute_increment
run_same_minute_zero_padding
run_same_minute_gap
run_other_minute_same_day_ignored
run_legacy_format_ignored
run_malformed_sequence_ignored
run_missing_dir
run_upper_bound
run_invalid_timestamp
run_local_clock_format

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
