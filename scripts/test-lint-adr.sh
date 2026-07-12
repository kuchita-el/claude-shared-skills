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
LINT_ADR="$REPO_ROOT/scripts/lint-adr.sh"
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

# ==== AC1: lint-adr.sh レイヤ1（front-matter スキーマ検証） ====

# valid corpus は違反0件で exit 0 になること
# （旧形式スキップ・却下/提案中/廃止済みが合法であることを含む）
run_layer1_valid() {
    local corpus="$FIXTURES_DIR/valid/01-mixed-validity"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC1(valid): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] AC1: valid corpus(01-mixed-validity) は exit 0\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC1: valid corpus(01-mixed-validity) は exit 0 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

# invalid corpus は exit 1 ＋ 該当違反種別メッセージの部分一致になること
# 引数: corpus名 期待メッセージ部分文字列 ラベル
run_layer1_invalid() {
    local corpus_name="$1" expect_substr="$2" label="$3"
    local corpus="$FIXTURES_DIR/invalid/$corpus_name"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] %s: lint-adr.sh not found: %s\n' "$label" "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] %s: missing fixture corpus: %s\n' "$label" "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 1 ]; then
        printf '[PASS] %s: exit 1\n' "$label"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: exit 1 を期待したが %d\n  output:\n%s\n' "$label" "$rc" "$output"
        failed=$((failed + 1))
    fi

    assert_contains "$output" "$expect_substr" "$label: 違反メッセージ部分一致"
}

run_layer1_valid
run_layer1_invalid "01-status-missing" "status が空です" "AC1: status 欠落"
run_layer1_invalid "02-validity-missing" "validity が空です" "AC1: status=承認済み かつ validity 欠落"
run_layer1_invalid "03-superseded-by-missing" "superseded-by が空です" "AC1: validity=上書き済み かつ superseded-by 欠落"

# ADR_DIR が存在しない場合は exit 2（fixture 不要、不在パスを渡すだけ）
run_layer1_missing_dir() {
    local corpus="$FIXTURES_DIR/invalid/__nonexistent__"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC1: lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 2 ]; then
        printf '[PASS] AC1: ディレクトリ不在は exit 2\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC1: ディレクトリ不在は exit 2 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

run_layer1_missing_dir

# 複数 ADR 同時違反: 1件目で早期打ち切りせず全件出力されること
run_layer1_multi_violation() {
    local corpus="$FIXTURES_DIR/invalid/06-multi-violation"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC1(multi): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC1(multi): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 1 ]; then
        printf '[PASS] AC1(multi): exit 1\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC1(multi): exit 1 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi

    assert_contains "$output" "ADR-20260601-multi-violation-status-missing.md: status が空です" "AC1(multi): 1件目(status欠落)の違反メッセージ"
    assert_contains "$output" "ADR-20260602-multi-violation-superseded-by-missing.md: validity=上書き済み だが superseded-by が空です" "AC1(multi): 2件目(superseded-by欠落)の違反メッセージ"
}

run_layer1_multi_violation

# ==== 後続 Task 3〜4 で
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
