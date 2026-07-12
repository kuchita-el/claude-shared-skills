#!/usr/bin/env bash
# ADR drift-lint のテストランナー
#
# scripts/fixtures/lint-adr/{valid,invalid}/ の共有 corpus を使い、
# gen-adr-index.sh と lint-adr.sh（後続 Task で追加）の振る舞いを検証する。
#
# 使い方:
#   bash scripts/test-lint-adr.sh
#
# exit code:
#   0: 全アサーションパス
#   1: いずれか失敗
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN_INDEX="$REPO_ROOT/scripts/gen-adr-index.sh"
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures/lint-adr"

passed=0
failed=0
total=0

# 文字列 haystack に needle を含むことをアサート
assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    total=$((total + 1))
    if [[ "$haystack" == *"$needle"* ]]; then
        printf '[PASS] %s\n' "$label"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: expected output to contain "%s"\n' "$label" "$needle"
        failed=$((failed + 1))
    fi
}

# 文字列 haystack に needle を含まないことをアサート
assert_not_contains() {
    local haystack="$1" needle="$2" label="$3"
    total=$((total + 1))
    if [[ "$haystack" != *"$needle"* ]]; then
        printf '[PASS] %s\n' "$label"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: expected output NOT to contain "%s"\n' "$label" "$needle"
        failed=$((failed + 1))
    fi
}

# ==== AC4: gen-adr-index.sh が validity=有効 の ADR のみを列挙する ====
run_ac4() {
    local corpus="$FIXTURES_DIR/valid/01-mixed-validity"

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC4: missing fixture corpus: %s\n' "$corpus"
        return
    fi

    if [ ! -f "$GEN_INDEX" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC4: gen-adr-index.sh not found: %s\n' "$GEN_INDEX"
        return
    fi

    local output rc
    set +e
    output=$(bash "$GEN_INDEX" "$corpus" 2>&1)
    rc=$?
    set -e

    if [ "$rc" -ne 0 ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC4: gen-adr-index.sh exited %d, expected 0\n  output:\n%s\n' "$rc" "$output"
        return
    fi

    assert_contains "$output" "ADR-20260101-sample-decision" "AC4: 有効ADR1件目(sample-decision)が含まれる"
    assert_contains "$output" "ADR-20260102-second-decision" "AC4: 有効ADR2件目(second-decision)が含まれる"
    assert_not_contains "$output" "ADR-20260103-old-decision" "AC4: 上書き済みADRが含まれない"
    assert_not_contains "$output" "ADR-20260104-abandoned-decision" "AC4: 廃止済みADRが含まれない"
    assert_not_contains "$output" "ADR-20260105-rejected-decision" "AC4: 却下ADRが含まれない"
    assert_not_contains "$output" "ADR-20260106-proposed-decision" "AC4: 提案中ADRが含まれない"
    assert_not_contains "$output" "ADR-20260107-legacy-format-decision" "AC4: 旧形式ADRが含まれない"
}

run_ac4

# ==== 後続 Task 2〜4 でレイヤ1（front-matter スキーマ）/
#      レイヤ2（index 同期）/ レイヤ3（相互参照双方向性）の
#      invalid corpus 検査ブロックをここに追記する ====

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
