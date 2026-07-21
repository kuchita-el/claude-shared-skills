#!/usr/bin/env bash
# ADR drift-lint のテストランナー
#
# 同ディレクトリの fixtures/lint-adr/{valid,invalid}/ の共有 corpus を使い、
# gen-adr-index.sh と lint-adr.sh の振る舞いを検証する。
#
# 使い方:
#   bash plugins/adr/scripts/test-lint-adr.sh
#
# exit code:
#   0: 全アサーションパス
#   1: いずれか失敗
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN_INDEX="$PLUGIN_ROOT/scripts/gen-adr-index.sh"
LINT_ADR="$PLUGIN_ROOT/scripts/lint-adr.sh"
FIXTURES_DIR="$PLUGIN_ROOT/scripts/fixtures/lint-adr"

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
# しうる面＝manage-adr のスキル面（#515 反転後の新在処）に対して行う。host 固有の
# docs/adr/README.md はプラグイン非搭載のため、可搬な本テストの surface からは除外する。
# 除去検査の検査語は必ず見出しでアンカーする。裸の部分文字列にすると「節の復活」ではなく
# 「節を名指しすること」を禁じてしまい、廃止の経緯を説明する散文まで書けなくなるため。

MANAGE_ADR_DIR="$PLUGIN_ROOT/skills/manage-adr"
EDIT_DECISION="$MANAGE_ADR_DIR/references/edit-decision.md"

# 除去検査の対象面を構成するファイルを明示列挙する。surface を glob（references/*.md）
# で組み立てると、ファイルが削除されても glob が静かに縮小するだけで検査が素通りし、
# 対象面が無言で狭まる。glob 結果に存在チェックを掛けても同じ理由で検知できないため、
# 期待リストを固定し、存在チェックと surface の構成元をこのリストに一致させる。
AC5_SURFACE_FILES=(
    "$MANAGE_ADR_DIR/SKILL.md"
    "$MANAGE_ADR_DIR/references/adr-model.md"
    "$MANAGE_ADR_DIR/references/adr-scoping.md"
    "$EDIT_DECISION"
    "$MANAGE_ADR_DIR/references/io-examples.md"
    "$MANAGE_ADR_DIR/references/template.md"
    "$MANAGE_ADR_DIR/references/transitions.md"
)

run_ac5_edit_mechanism() {
    local f actual
    for f in "${AC5_SURFACE_FILES[@]}"; do
        if [ ! -f "$f" ]; then
            total=$((total + 1))
            failed=$((failed + 1))
            printf '[FAIL] AC5: surface file not found: %s\n' "$f"
            return
        fi
    done

    # 逆向きの縮小（参照ファイルが増えたのに期待リストへ未登録＝その面だけ検査から漏れる）
    # も検知する。nullglob で空マッチ時にリテラルが残らないことを明示する。
    shopt -s nullglob
    local actual_refs=( "$MANAGE_ADR_DIR"/references/*.md )
    shopt -u nullglob
    for actual in "${actual_refs[@]}"; do
        case " ${AC5_SURFACE_FILES[*]} " in
            *" $actual "*) ;;
            *)
                total=$((total + 1))
                failed=$((failed + 1))
                printf '[FAIL] AC5: surface file list does not cover: %s\n' "$actual"
                return
                ;;
        esac
    done

    local edit_content surface
    edit_content=$(cat "$EDIT_DECISION")
    surface=$(cat "${AC5_SURFACE_FILES[@]}")

    assert_contains "$edit_content" "3段構え" "AC5: 3段構え編集機構の対応表が edit-decision.md に存在する"
    assert_contains "$edit_content" "些末" "AC5: decision tree（些末/非core/core 判定フロー）が edit-decision.md に存在する"
    assert_not_contains "$surface" "## モデル制約由来の設計判断インデックス" "AC5: 旧モデル制約由来の設計判断インデックス節が manage-adr スキル面から除去されている"
    assert_not_contains "$surface" "### Amended（部分改訂）" "AC5: 旧 Amended（部分改訂）手順節が manage-adr スキル面から除去されている"
}

run_ac5_edit_mechanism

# ==== #522: レイヤ4（有効ADRの Related/park 参照の退役・dangling 検査） ====
# 出典 ADR-20260720-4 §3（非 Supersede 参照妥当性 lint）＋ Issue #522（退役参照検査・
# 判定単位の書式非依存化）。有効 ADR の `## 関連ADR`（Related:）／`## 保留した決定`（park）
# の先頭 ADR stem を、行頭バレット有無・markdown リンク形式有無を問わず抽出し、参照先が
# 退役（上書き済み/廃止済み）なら参照先退役違反、非存在なら dangling 参照違反として報告する。
# park は dangling のみ（退役非適用＝J4）。ラベルは #522 併記で既存 run_ac5_edit_mechanism
# （#515 の別 AC5）との混同を避ける。

# AC1/AC2(穴1): バレット無し＋plain の Related が廃止済みADRを指す → 参照先退役違反
run_xref_list_case \
    "$FIXTURES_DIR/invalid/18-related-retired-no-bullet" 1 \
    "#522(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反" \
    "contains:参照先退役違反" \
    "contains:ADR-20261102-related-retired-nb-target"

# AC1/AC2(穴2): リンク形式の Related が上書き済みADRを指す → 参照先退役違反（相互参照違反は出ない）
run_xref_list_case \
    "$FIXTURES_DIR/invalid/19-related-retired-link" 1 \
    "#522(AC1/AC2-穴2): リンク形式 Related が退役ADRを指すと参照先退役違反" \
    "contains:参照先退役違反" \
    "contains:ADR-20261112-related-retired-link-old" \
    "notcontains:相互参照違反"

# gap1(セルフレビュー反映): リンクラベルが説明文で stem がパス部のみの Related
# （`- Related: [詳細](./ADR-X.md)`）でも先頭 stem 抽出で退役を検出する（書式非依存の
# 適用範囲＝リンクラベル書式。旧実装は `Related:` 直後の stem 隣接を前提とし取り漏らした）
run_xref_list_case \
    "$FIXTURES_DIR/invalid/22-related-link-label" 1 \
    "#522(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出" \
    "contains:参照先退役違反" \
    "contains:ADR-20261302-related-linklabel-target"

# AC6/AC8: Related が非存在 slug を指す → dangling 参照違反（解決不能＝fail-safe を統合）
run_xref_list_case \
    "$FIXTURES_DIR/invalid/20-related-dangling" 1 \
    "#522(AC6/AC8): Related が非存在slugを指すと dangling 参照違反" \
    "contains:dangling 参照違反" \
    "contains:ADR-20261299-does-not-exist"

# AC6/AC7: park 欄が非存在 slug を指す → dangling 参照違反（park も dangling 検査の対象）
run_xref_list_case \
    "$FIXTURES_DIR/invalid/21-park-dangling" 1 \
    "#522(AC6/AC7): 保留した決定が非存在slugを指すと dangling 参照違反" \
    "contains:dangling 参照違反" \
    "contains:ADR-20261298-park-missing"

# AC2/AC7(誤検出回避): 全4書式の有効参照・散文の退役引用・park→有効/退役(存在)は
# いずれも違反にならず exit 0（先頭stem抽出の要、park は dangling のみ＝J4 の正方向固定）
run_xref_list_case \
    "$FIXTURES_DIR/valid/06-related-valid" 0 \
    "#522(AC2/AC7-誤検出回避): 全書式の有効参照・散文退役引用・park退役(存在)は exit 0" \
    "notcontains:参照先退役違反" \
    "notcontains:dangling 参照違反"

# #522(park link dedup): park 参照が markdown リンク形式（`[stem](./stem.md)`）でも
# dangling 違反は1回のみ報告する（ラベル部とパス部で同一 stem を二重報告しない回帰。
# invalid/21 の park 参照はリンク形式）。
run_layer4_park_link_dedup() {
    local corpus="$FIXTURES_DIR/invalid/21-park-dangling"

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] #522(park link dedup): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output count
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    count=$(printf '%s\n' "$output" | grep -c "ADR-20261298-park-missing")
    set -e

    total=$((total + 1))
    if [ "$count" -eq 1 ]; then
        printf '[PASS] #522(park link dedup): リンク形式 park dangling は1回のみ報告（count=%d）\n' "$count"
        passed=$((passed + 1))
    else
        printf '[FAIL] #522(park link dedup): リンク形式 park dangling は1回報告を期待したが %d 回\n  output:\n%s\n' "$count" "$output"
        failed=$((failed + 1))
    fi
}

run_layer4_park_link_dedup

# #522(related dup dedup): 同一 source が複数の `Related:` 行から同じ退役 ADR を指しても
# 参照先退役違反は1回のみ報告する（extract_body_related のファイル内 dedup。park 側
# run_layer4_park_link_dedup と対称の保護。dedup を外すと二重報告に戻る）。
run_layer4_related_dup_dedup() {
    local corpus="$FIXTURES_DIR/invalid/23-related-dup-report"

    if [ ! -d "$corpus" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] #522(related dup dedup): missing fixture corpus: %s\n' "$corpus"
        return
    fi

    local output count
    set +e
    output=$(bash "$LINT_ADR" "$corpus" 2>&1)
    count=$(printf '%s\n' "$output" | grep -c "ADR-20261402-related-dup-target")
    set -e

    total=$((total + 1))
    if [ "$count" -eq 1 ]; then
        printf '[PASS] #522(related dup dedup): 複数Related行が同一退役ADRを指しても違反は1回のみ（count=%d）\n' "$count"
        passed=$((passed + 1))
    else
        printf '[FAIL] #522(related dup dedup): 1回報告を期待したが %d 回\n  output:\n%s\n' "$count" "$output"
        failed=$((failed + 1))
    fi
}

run_layer4_related_dup_dedup

# AC5: レイヤ4仕様のヘッダ成文化。判定単位の書式非依存化・退役/dangling 検査の仕様を
# lint-adr.sh ヘッダに既存レイヤ1〜3 と同形式（決定を ADR 参照で明示）で成文化する。
# 決定出典は ADR-20260720-4 §3。削除で red 化する必須アサート（run_ac5_edit_mechanism に倣う）。
run_layer4_header_spec() {
    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] #522(AC5): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local content
    content=$(cat "$LINT_ADR")
    assert_contains "$content" "レイヤ4" "#522(AC5): ヘッダにレイヤ4の記述が存在する"
    assert_contains "$content" "ADR-20260720-4" "#522(AC5): ヘッダにレイヤ4の決定出典 ADR-20260720-4 が明記されている"
}

run_layer4_header_spec

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
