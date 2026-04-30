#!/usr/bin/env bash
# DDDドキュメントリントのテストランナー
#
# scripts/fixtures/lint-domain-doc/{valid,invalid}/*.md を順次 lint し、
# valid は exit 0、invalid は exit 1 と期待メッセージ部分一致をアサートする。
#
# 使い方:
#   bash scripts/test-lint-domain-doc.sh
#
# exit code:
#   0: 全 fixture パス
#   1: いずれか失敗
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$REPO_ROOT/scripts/lint-domain-doc.sh"
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures/lint-domain-doc"

# valid 群: 期待 exit code 0
valid_fixtures=(
    "01-command-only.md"
    "02-command-with-policy.md"
    "03-u-row-verbs.md"
    "04-mermaid-and-symbols.md"
)

# invalid 群: 期待 exit code 1 + 期待メッセージ部分文字列（| 区切りで AND 検査）
invalid_fixtures=(
    "01-state-transition-section.md"
    "02-non-u-row-ending.md"
    "03-failure-reason-as-type.md"
    "04-missing-trigger.md"
)
declare -A invalid_expected
invalid_expected["01-state-transition-section.md"]="廃止セクション|状態遷移"
invalid_expected["02-non-u-row-ending.md"]="命名規約|タスクを処理中|う段終止形"
invalid_expected["03-failure-reason-as-type.md"]="廃止記法|失敗理由"
invalid_expected["04-missing-trigger.md"]="契機欠落"

passed=0
failed=0
total=$((${#valid_fixtures[@]} + ${#invalid_fixtures[@]}))

run_lint() {
    local path="$1"
    set +e
    output=$(bash "$LINT" "$path" 2>&1)
    rc=$?
    set -e
}

# valid 群
for name in "${valid_fixtures[@]}"; do
    path="$FIXTURES_DIR/valid/$name"
    if [ ! -f "$path" ]; then
        printf '[FAIL] missing fixture: %s\n' "$path"
        failed=$((failed + 1))
        continue
    fi
    run_lint "$path"
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] valid/%s (exit=0)\n' "$name"
        passed=$((passed + 1))
    else
        printf '[FAIL] valid/%s expected exit=0, got=%d\n  output:\n%s\n' "$name" "$rc" "$output"
        failed=$((failed + 1))
    fi
done

# invalid 群
for name in "${invalid_fixtures[@]}"; do
    path="$FIXTURES_DIR/invalid/$name"
    if [ ! -f "$path" ]; then
        printf '[FAIL] missing fixture: %s\n' "$path"
        failed=$((failed + 1))
        continue
    fi
    expected_pattern="${invalid_expected[$name]}"
    run_lint "$path"
    msg_ok=1
    missing=""
    IFS='|' read -ra patterns <<<"$expected_pattern"
    for p in "${patterns[@]}"; do
        if [[ "$output" != *"$p"* ]]; then
            msg_ok=0
            missing="$p"
            break
        fi
    done
    if [ "$rc" -eq 1 ] && [ "$msg_ok" -eq 1 ]; then
        printf '[PASS] invalid/%s (exit=1, msg matched)\n' "$name"
        passed=$((passed + 1))
    else
        printf '[FAIL] invalid/%s expected exit=1 with msg containing "%s", got exit=%d (missing="%s")\n  output:\n%s\n' \
            "$name" "$expected_pattern" "$rc" "$missing" "$output"
        failed=$((failed + 1))
    fi
done

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
