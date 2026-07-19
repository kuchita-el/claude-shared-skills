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

# ==== #500: レイヤ1へ語彙メンバシップ検査＋遷移表の組み合わせ検査を追加 ====
#
# ADR-20260711-3 決定5 は レイヤ1 を「決定2 のスキーマ必須ルール（遷移表）を
# 満たすこと」と定義するが、実装は空判定3件のみで語彙・組み合わせを検査して
# いなかった。以下はその欠落を塞ぐ回帰ケース。
#
# 語彙メンバシップ: 値が非空でも正本の語彙に属さなければ違反にする。
# `gen-adr-index.sh` は `validity: 有効` の完全一致でしか採録しないため、
# 語彙外の値は index から静かに脱落する一方、旧実装では lint を通過していた
# （新規追加時はコミット済み index と再生成 index の双方に載らず一致するため
#  レイヤ2 も原理的に発火しない）。
run_layer1_invalid "12-status-unknown-vocab" "status の値 \"Accepted\" が語彙にありません" "AC1(#500): status 語彙外（旧英文状態）"
run_layer1_invalid "13-validity-unknown-vocab" "validity の値 \"有郊\" が語彙にありません" "AC1(#500): validity 語彙外（誤字）"

# 組み合わせ: 語彙に属する値どうしでも、決定2 の遷移表に無い行は違反にする。
run_layer1_invalid "14-proposed-with-validity" "status=提案中 だが validity が空ではありません" "AC1(#500): 提案中 かつ validity 非空"
run_layer1_invalid "15-rejected-with-validity" "status=却下 だが validity が空ではありません" "AC1(#500): 却下 かつ validity 非空"
run_layer1_invalid "16-active-with-superseded-by" "validity=有効 だが superseded-by が空ではありません" "AC1(#500): 有効 かつ superseded-by 非空"
run_layer1_invalid "17-abandoned-with-superseded-by" "validity=廃止済み だが superseded-by が空ではありません" "AC1(#500): 廃止済み かつ superseded-by 非空"

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

# ==== #497: レイヤ3を list-aware N対1 検査へ拡張（リスト値 superseded-by の 1→N 分割対応） ====
# 正本 ADR-20260711-3 決定5: 分割による 1→N は A が複数後継を列挙し、各後継が A を
# 逆参照する N対1。従来は superseded-by を行まるごと単一 stem として扱っていたため、
# 正当な分割（リスト値）を相互参照違反として誤検出していた。

# 汎用ランナー: corpus を lint し exit code と（任意の）含む/含まない部分文字列をアサート
# 引数: corpus_path 期待exit ラベル [contains:文字列 | notcontains:文字列 ...]
run_xref_list_case() {
    local corpus="$1" expect_rc="$2" label="$3"
    shift 3

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
    if [ "$rc" -eq "$expect_rc" ]; then
        printf '[PASS] %s: exit %d\n' "$label" "$expect_rc"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s: exit %d を期待したが %d\n  output:\n%s\n' "$label" "$expect_rc" "$rc" "$output"
        failed=$((failed + 1))
    fi

    local spec kind needle
    for spec in "$@"; do
        kind="${spec%%:*}"
        needle="${spec#*:}"
        case "$kind" in
            contains) assert_contains "$output" "$needle" "$label: \"$needle\" を含む" ;;
            notcontains) assert_not_contains "$output" "$needle" "$label: \"$needle\" を含まない" ;;
        esac
    done
}

# AC1: リスト値の正常分割（A・B 両ファイル存在＋双方が本文逆参照）は違反0件で exit 0
run_xref_list_case \
    "$FIXTURES_DIR/valid/04-xref-list" 0 \
    "#497(AC1): リスト値正常分割は exit 0"

# AC2(forward逆参照欠落): 後継Bのみ本文逆参照を欠く → Bのエッジのみ forward 違反、
# 充足側の後継Aは違反メッセージに現れない
run_xref_list_case \
    "$FIXTURES_DIR/invalid/08-xref-list-forward-missing" 1 \
    "#497(AC2-forward): 後継Bのみ forward 違反" \
    "contains:相互参照違反" \
    "contains:ADR-20260812-xref-list-fwd-new-b.md" \
    "notcontains:ADR-20260811-xref-list-fwd-new-a"

# AC3(reverse列挙欠落): 非列挙の第三ADR Cが本文で old を Supersedes 宣言 →
# Cのエッジが reverse 違反、列挙済みのA・Bは違反にならない
run_xref_list_case \
    "$FIXTURES_DIR/invalid/09-xref-list-reverse-missing" 1 \
    "#497(AC3-reverse): 非列挙Cのみ reverse 違反" \
    "contains:相互参照違反（逆方向" \
    "contains:ADR-20260913-xref-list-rev-extra-c" \
    "notcontains:ADR-20260911-xref-list-rev-new-a.md の本文"

# AC2(forwardファイル不在・リスト要素単位): 後継Bの実ファイルが存在しない →
# Bのエッジのみ「参照先が見つかりません」違反、実在する後継Aは独立して照合へ進み違反にならない
run_xref_list_case \
    "$FIXTURES_DIR/invalid/10-xref-list-forward-file-missing" 1 \
    "#497(AC2-file-missing): 後継Bのみ参照先不在違反" \
    "contains:ADR-20261012-xref-list-fm-missing-b" \
    "contains:が見つかりません" \
    "notcontains:ADR-20261011-xref-list-fm-new-a"

# PRレビュー反映(空要素のみ): superseded-by がカンマ・空白のみで有効な参照先 stem を
# 1つも含まない病的値は、レイヤ1の raw 空判定を通過し forward 分割結果が0件になる。
# 「validity=上書き済み ⟹ 少なくとも1件の後継が照合される」不変条件を回復するため
# 独立違反として検出する（かつ set -e 下でスクリプトが異常終了せず exit 1 を返す）。
run_xref_list_case \
    "$FIXTURES_DIR/invalid/11-xref-list-empty-superseded" 1 \
    "#497(空要素のみ): 有効な参照先stem 0件を違反として検出" \
    "contains:有効な参照先 stem がありません"

# PRレビュー反映(末尾カンマ): 末尾カンマ由来の空要素はスキップされ、有効な後継1本が
# 正しく照合される（末尾カンマは無害）。空要素処理が後方互換を壊さないことの回帰。
run_xref_list_case \
    "$FIXTURES_DIR/valid/05-xref-list-trailing-comma" 0 \
    "#497(末尾カンマ): 末尾カンマは無害で exit 0"

# ==== AC5: 新スキーマの編集機構（decision tree・3段構え対応表）の文書化と旧記述の除去 ====
# #515 で運用ルールの正本が docs/adr/README.md から manage-adr スキルへ反転したため、
# 存在検査の対象を移設先（edit-decision.md）へ張り替える。除去検査は、旧記述が再混入
# しうる面が「旧在処＝README」と「新在処＝manage-adr のスキル面」の双方に広がったため、
# 両者を連結した面に対して行う（README だけを見ると新在処への再混入を取り逃がす）。

README_ADR="$REPO_ROOT/docs/adr/README.md"
MANAGE_ADR_DIR="$REPO_ROOT/plugins/dev-workflow/skills/manage-adr"
EDIT_DECISION="$MANAGE_ADR_DIR/references/edit-decision.md"

run_ac5_edit_mechanism() {
    local f
    for f in "$README_ADR" "$EDIT_DECISION" "$MANAGE_ADR_DIR/SKILL.md"; do
        if [ ! -f "$f" ]; then
            total=$((total + 1))
            failed=$((failed + 1))
            printf '[FAIL] AC5: file not found: %s\n' "$f"
            return
        fi
    done

    local edit_content surface
    edit_content=$(cat "$EDIT_DECISION")
    surface=$(cat "$README_ADR" "$MANAGE_ADR_DIR/SKILL.md" "$MANAGE_ADR_DIR"/references/*.md)

    assert_contains "$edit_content" "3段構え" "AC5: 3段構え編集機構の対応表が edit-decision.md に存在する"
    assert_contains "$edit_content" "些末" "AC5: decision tree（些末/非core/core 判定フロー）が edit-decision.md に存在する"
    assert_not_contains "$surface" "モデル制約由来の設計判断インデックス" "AC5: 旧モデル制約由来の設計判断インデックス節が README・manage-adr の双方から除去されている"
    assert_not_contains "$surface" "### Amended（部分改訂）" "AC5: 旧 Amended（部分改訂）手順節が README・manage-adr の双方から除去されている"
}

run_ac5_edit_mechanism

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
