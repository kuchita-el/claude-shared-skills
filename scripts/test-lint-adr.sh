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

# ==== 回帰: gen-adr-index.sh の validity 抽出は末尾空白をトリムする ====
# （lint-adr.sh の trim() と抽出・判定を一致させる。トリムしないと
#   validity: 有効<末尾空白> の ADR が gen 側からは「有効でない」扱いで
#   index から静かに除外される一方、lint レイヤ1はトリム済みで「有効」
#   判定するため、レイヤ2（gen 出力と index.md の diff）でも drift として
#   検出されず ADR が index から無言で消えるドリフトの回帰）
run_whitespace_validity() {
    local corpus="$FIXTURES_DIR/valid/03-whitespace-validity"

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] 回帰(whitespace-validity): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    if [ ! -f "$GEN_INDEX" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] 回帰(whitespace-validity): gen-adr-index.sh not found: %s\n' "$GEN_INDEX"
        return
    fi

    local gen_output gen_rc
    set +e
    gen_output=$(bash "$GEN_INDEX" "$corpus" 2>&1)
    gen_rc=$?
    set -e

    if [ "$gen_rc" -ne 0 ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] 回帰(whitespace-validity): gen-adr-index.sh exited %d, expected 0\n  output:\n%s\n' "$gen_rc" "$gen_output"
        return
    fi

    assert_contains "$gen_output" "ADR-20260201-trailing-space-decision" "回帰(whitespace-validity): validity末尾空白ADRがindexに含まれる"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] 回帰(whitespace-validity): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local lint_output lint_rc
    set +e
    lint_output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    lint_rc=$?
    set -e

    total=$((total + 1))
    if [ "$lint_rc" -eq 0 ]; then
        printf '[PASS] 回帰(whitespace-validity): lint-adr.sh は exit 0（レイヤ2 drift 誤検出なし）\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] 回帰(whitespace-validity): lint-adr.sh は exit 0 を期待したが %d\n  output:\n%s\n' "$lint_rc" "$lint_output"
        failed=$((failed + 1))
    fi
}

run_whitespace_validity

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

# ==== AC3: lint-adr.sh レイヤ2（index 同期） ====

# 古い index.md（有効ADRを1件欠く）を同梱した corpus は exit 1 ＋ 同期違反メッセージ
run_layer2_index_drift() {
    local corpus="$FIXTURES_DIR/invalid/04-index-drift"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC3: lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC3: missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 1 ]; then
        printf '[PASS] AC3: index-drift corpus は exit 1\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC3: index-drift corpus は exit 1 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi

    assert_contains "$output" "index 同期違反" "AC3: index-drift corpus の同期違反メッセージ"
}

run_layer2_index_drift

# valid 01-mixed-validity はレイヤ2（index 同期）追加後も exit 0 を維持すること
run_layer2_valid_still_passes() {
    local corpus="$FIXTURES_DIR/valid/01-mixed-validity"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC3(valid): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] AC3: valid corpus(01-mixed-validity) はレイヤ2追加後も exit 0\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC3: valid corpus(01-mixed-validity) はレイヤ2追加後も exit 0 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

run_layer2_valid_still_passes

# ==== AC2: lint-adr.sh レイヤ3（相互参照双方向性） ====

# superseded-by=B を持つが B の本文に Supersedes 逆参照が無い corpus は
# exit 1 ＋ 相互参照違反メッセージ
run_layer3_xref_missing() {
    local corpus="$FIXTURES_DIR/invalid/05-xref-missing"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC2: lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC2: missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 1 ]; then
        printf '[PASS] AC2: xref-missing corpus は exit 1\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC2: xref-missing corpus は exit 1 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi

    assert_contains "$output" "相互参照違反" "AC2: xref-missing corpus の相互参照違反メッセージ"
}

run_layer3_xref_missing

# 相互参照検証専用の valid corpus（双方向一致ペア＋Amends凍結例）は exit 0
run_layer3_xref_valid() {
    local corpus="$FIXTURES_DIR/valid/02-xref-valid"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC2(valid): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC2(valid): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] AC2: xref-valid corpus(02-xref-valid) は exit 0\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC2: xref-valid corpus(02-xref-valid) は exit 0 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

run_layer3_xref_valid

# valid 01-mixed-validity はレイヤ3（相互参照双方向性）追加後も exit 0 を維持すること
run_layer3_mixed_validity_still_passes() {
    local corpus="$FIXTURES_DIR/valid/01-mixed-validity"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC2(mixed-validity): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] AC2: valid corpus(01-mixed-validity) はレイヤ3追加後も exit 0\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] AC2: valid corpus(01-mixed-validity) はレイヤ3追加後も exit 0 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

run_layer3_mixed_validity_still_passes

# ==== PRレビュー反映: レイヤ3を真の双方向（⟺）にする ====
# 正本 ADR-20260711-3 決定5: A.superseded-by=B ⟺ B本文 Supersedes: A。
# 従来は front-matter 起点（forward）のみの片方向照合だったため、
# 本文で Supersedes 宣言したが front-matter 更新を忘れたケース（逆方向の
# ドリフト）を検出できなかった。逆方向（本文 Supersedes 起点で
# front-matter superseded-by を照合）を追加する。

# 本文が Supersedes 宣言しているが対象ADRの front-matter superseded-by が
# 欠落/不一致（更新忘れ）の corpus は exit 1 ＋ 逆方向と分かる違反メッセージ
run_layer3_xref_reverse_missing() {
    local corpus="$FIXTURES_DIR/invalid/07-xref-reverse-missing"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] PRレビュー反映(reverse-missing): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] PRレビュー反映(reverse-missing): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 1 ]; then
        printf '[PASS] PRレビュー反映(reverse-missing): exit 1\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] PRレビュー反映(reverse-missing): exit 1 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi

    assert_contains "$output" "相互参照違反（逆方向" "PRレビュー反映(reverse-missing): 逆方向と分かる違反メッセージ"
    assert_contains "$output" "ADR-20260701-xref-reverse-missing-old" "PRレビュー反映(reverse-missing): front-matter更新忘れ側(旧ADR)の言及"
}

run_layer3_xref_reverse_missing

# 入れ子（インデント）バレット `  - Supersedes: ...` を持つ双方向一致ペアは
# 誤検知せず exit 0（02-xref-valid に追加した nested ペアで確認）
run_layer3_xref_nested_bullet_valid() {
    local corpus="$FIXTURES_DIR/valid/02-xref-valid"

    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] PRレビュー反映(nested-bullet): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local output rc
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    rc=$?
    set -e

    total=$((total + 1))
    if [ "$rc" -eq 0 ]; then
        printf '[PASS] PRレビュー反映(nested-bullet): 入れ子バレット双方向一致ペアを含む02-xref-validはexit 0\n'
        passed=$((passed + 1))
    else
        printf '[FAIL] PRレビュー反映(nested-bullet): exit 0 を期待したが %d\n  output:\n%s\n' "$rc" "$output"
        failed=$((failed + 1))
    fi
}

run_layer3_xref_nested_bullet_valid

# ==== AC5: docs/adr/README.md の新スキーマ改訂（decision tree・3段構え対応表の存在、旧記述の除去） ====

README_ADR="$REPO_ROOT/docs/adr/README.md"

run_ac5_readme() {
    if [ ! -f "$README_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] AC5: docs/adr/README.md not found: %s\n' "$README_ADR"
        return
    fi

    local content
    content=$(cat "$README_ADR")

    assert_contains "$content" "3段構え" "AC5: 3段構え編集機構の対応表が存在する"
    assert_contains "$content" "些末" "AC5: decision tree（些末/非core/core 判定フロー）が存在する"
    assert_not_contains "$content" "モデル制約由来の設計判断インデックス" "AC5: 旧モデル制約由来の設計判断インデックス節が除去されている"
    assert_not_contains "$content" "### Amended（部分改訂）" "AC5: 旧 Amended（部分改訂）手順節が除去されている"
}

run_ac5_readme

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
