#!/usr/bin/env bash
# ADR drift-lint のテストランナー
#
# 同ディレクトリの fixtures/lint-adr/{valid,invalid}/ の共有 corpus を使い、
# 配布物内（plugins/adr/scripts/）の gen-adr-index.sh と lint-adr.sh の振る舞いを検証する。
#
# レイヤ5 の識別子重複検査は、識別子の時刻部が分粒度であるために発番側（next-adr-id.sh）では
# 構造的に消せない残余——同一分・別ブランチ・同一連番の重複——を受け止める最後の関門である。
# 本テストはその検出を固定する（旧手順下では重複が1か月以上検出されないまま残った実測がある）。
#
# レイヤ4 の判定単位——`Related:` 以降で最初に現れる ADR stem を、行頭バレットの有無・markdown
# リンクの有無・リンクラベルの書式を問わず取ること——はどの ADR にも成文化されていない。本テストと
# fixtures/lint-adr/ がその正であり、書式非依存性を境界事例として固定する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# 使い方:
#   bash scripts/test-lint-adr.sh
#
# exit code:
#   0: 全アサーションパス
#   1: いずれか失敗
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/adr"                    # 配布物ルート
GEN_INDEX="$PLUGIN_ROOT/scripts/gen-adr-index.sh"       # 配布物内（被テスト）
LINT_ADR="$PLUGIN_ROOT/scripts/lint-adr.sh"             # 配布物内（被テスト）
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures/lint-adr"     # 配布物外（fixture）

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

# ==== レイヤ5: ファイル名形式・識別子重複・H1 整合 ====
# 仕様: レイヤ1〜4 はいずれもファイル本文（front-matter・本文節）と index を見るだけで、
# ファイル名そのものを検査しない。この欠落により同一識別子の ADR が2本 main へ到達した
# 実績がある。レイヤ5 はファイル名を第一級の検査対象に加える。
# 検査対象集合はレイヤ1 と同一（front-matter を持つ ADR のみ。旧形式はスキップ）。

# AC1: 形式不適合（時刻部の桁数不足）を検出する
run_xref_list_case \
    "$FIXTURES_DIR/invalid/24-filename-format-invalid" 1 \
    "(AC1/レイヤ5): 時刻部の桁数不足を形式違反として検出" \
    "contains:ファイル名形式違反" \
    "contains:ADR-2026120-01-bad-digits.md"

# AC1: 暦として妥当でない時刻部（月13）を検出する。桁数のみの照合では通過するため、
# next-adr-id.sh の発番側検証と同一の強度を lint 側にも置いていることの回帰。
run_xref_list_case \
    "$FIXTURES_DIR/invalid/25-filename-calendar-invalid" 1 \
    "(AC1/レイヤ5): 暦として不正な月を形式違反として検出" \
    "contains:ファイル名形式違反" \
    "contains:ADR-202613011030-01-bad-month.md"

# AC2: 同一識別子を持つ ADR が2本 → 重複した識別子と該当する全ファイル名を出力に含む
run_xref_list_case \
    "$FIXTURES_DIR/invalid/26-duplicate-adr-id" 1 \
    "(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙" \
    "contains:識別子重複違反" \
    "contains:ADR-202612051026-01" \
    "contains:ADR-202612051026-01-dup-first.md" \
    "contains:ADR-202612051026-01-dup-second.md"

# AC3: H1 見出しの識別子部がファイル名の識別子部と一致しない → 違反
run_xref_list_case \
    "$FIXTURES_DIR/invalid/27-h1-id-mismatch" 1 \
    "(AC3/レイヤ5): H1 の識別子部とファイル名の不整合を検出" \
    "contains:H1 整合違反" \
    "contains:ADR-202612061027-01-h1-mismatch.md"

# 制約（旧形式の扱い）: front-matter を持たない旧形式 ADR は、ファイル名が新形式に
# 適合しなくてもレイヤ5 の検査対象外（レイヤ1 のスキップと同一の対象集合）。
# 同居する新形式 ADR は正しく通過する。
run_xref_list_case \
    "$FIXTURES_DIR/valid/07-legacy-filename-skipped" 0 \
    "(制約/レイヤ5): front-matter 無しの旧形式ファイル名はスキップされ exit 0" \
    "notcontains:ファイル名形式違反" \
    "notcontains:H1 整合違反"

# AC2(緩い識別子抽出の保護): front-matter を持つ旧規約ファイル名の ADR 2本が同一識別子を
# 持つ corpus。識別子部の抽出を形式検査と同じ厳しさへ変えると重複が報告されなくなるため、
# 「抽出を形式検査より緩くした」というヘッダの判断をこの corpus が編集から守る。
# 形式違反も同時に報告されるため、識別子重複違反を明示的にアサートする。
run_xref_list_case \
    "$FIXTURES_DIR/invalid/28-legacy-duplicate-id" 1 \
    "(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出" \
    "contains:識別子重複違反" \
    "contains:ADR-20260621-01" \
    "contains:ADR-20260621-01-legacy-dup-a.md" \
    "contains:ADR-20260621-01-legacy-dup-b.md"

# AC1(接頭辞欠落): `ADR-` 接頭辞を欠くファイルは `ADR-*.md` グロブに当たらず全レイヤを
# 素通りする。レイヤ5 はこの経路も形式違反として塞ぐ。
run_xref_list_case \
    "$FIXTURES_DIR/invalid/29-missing-adr-prefix" 1 \
    "(AC1/レイヤ5): ADR- 接頭辞を欠く誤名ADRを形式違反として検出" \
    "contains:ファイル名形式違反" \
    "contains:202612091009-01-missing-prefix.md"

# AC5(誤検出回避): front-matter 内の YAML コメント行は行頭 `# ` に当たるが H1 ではない。
# 読み飛ばさないと H1 と誤認して偽陽性を報告し、commit 前ゲートがコミットを止める。
run_xref_list_case \
    "$FIXTURES_DIR/valid/08-frontmatter-yaml-comment" 0 \
    "(AC5/レイヤ5-誤検出回避): front-matter の YAML コメントを H1 と誤認しない" \
    "notcontains:H1 整合違反"

# AC5(誤検出回避): 既存の valid corpus にレイヤ5 が発火しない
run_xref_list_case \
    "$FIXTURES_DIR/valid/01-mixed-validity" 0 \
    "(AC5/レイヤ5-誤検出回避): 適合 corpus では発火しない" \
    "notcontains:ファイル名形式違反" \
    "notcontains:識別子重複違反" \
    "notcontains:H1 整合違反"

# AC7: レイヤ5仕様のヘッダ成文化。削除で red 化する必須アサート。
# 検索対象は `cat` の全文ではなく `set -euo pipefail` までのヘッダブロックに限定する。
# レイヤ名・検査名は変数コメントや printf の違反メッセージにも現れるため、全文検索では
# ヘッダの記述ブロックを丸ごと削除してもグリーンのままとなり、AC7 の成果物を保護できない。
run_layer5_header_spec() {
    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] (AC7): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    local header
    header=$(sed -n '1,/^set -euo pipefail/p' "$LINT_ADR")
    assert_contains "$header" "レイヤ5" "(AC7): ヘッダにレイヤ5の記述が存在する"
    assert_contains "$header" "ファイル名形式違反" "(AC7): ヘッダにファイル名形式検査の違反条件が成文化されている"
    assert_contains "$header" "識別子重複違反" "(AC7): ヘッダに識別子重複検査の違反条件が成文化されている"
    assert_contains "$header" "H1 整合違反" "(AC7): ヘッダに H1 整合検査の違反条件が成文化されている"
    assert_contains "$header" "検査対象集合はレイヤ1 と同一" "(AC7): ヘッダにレイヤ5の検査対象集合が成文化されている"
}

run_layer5_header_spec

# AC1(境界の面固定): 暦妥当性の境界は fixture では月13 しか通っておらず、
# ADR_STEM_PATTERN の日・時・分の選択肢を壊す編集が回帰に掛からない。
# パターンを直接叩いて MATCH/REJECT を突き合わせ、fixture を増やさずに境界を固定する。
run_layer5_stem_pattern() {
    if [ ! -f "$LINT_ADR" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] (AC1-境界): lint-adr.sh not found: %s\n' "$LINT_ADR"
        return
    fi

    # lint-adr.sh 本体を実行せずにパターン定義だけを取り出す（source すると
    # ADR_DIR 不在で exit 2 になるため、定義行を eval する）
    local pattern_def
    pattern_def=$(grep -m1 '^ADR_STEM_PATTERN=' "$LINT_ADR")
    if [ -z "$pattern_def" ]; then
        total=$((total + 1))
        failed=$((failed + 1))
        printf '[FAIL] (AC1-境界): ADR_STEM_PATTERN の定義が見つかりません\n'
        return
    fi
    eval "$pattern_def"

    # 期待MATCH: 境界値（月12・日31・時23・分59、連番99）と最小値
    local stem
    for stem in \
        "ADR-202601010000-01-a" \
        "ADR-202612312359-99-boundary-max" \
        "ADR-202601011030-10-seq-ten" \
        "ADR-202607262019-01-adr-id-timestamp-numbering"
    do
        total=$((total + 1))
        if [[ "$stem" =~ $ADR_STEM_PATTERN ]]; then
            printf '[PASS] (AC1-境界): 適合 stem を受理する: %s\n' "$stem"
            passed=$((passed + 1))
        else
            printf '[FAIL] (AC1-境界): 適合 stem を誤って拒否した: %s\n' "$stem"
            failed=$((failed + 1))
        fi
    done

    # 期待REJECT: AC1 が例示する暦不正（月13・日32・時24）＋分60・構造違反
    for stem in \
        "ADR-202613011030-01-bad-month" \
        "ADR-202601321030-01-bad-day" \
        "ADR-202601012430-01-bad-hour" \
        "ADR-202601011060-01-bad-minute" \
        "ADR-202601011030-1-short-seq" \
        "ADR-202601011030-00-zero-seq" \
        "ADR-202601011030-01-Bad-Upper" \
        "ADR-202601011030-01-double--hyphen" \
        "ADR-202601011030-01-trailing-" \
        "ADR-202601011030-01" \
        "ADR-2026010110301-01-too-long"
    do
        total=$((total + 1))
        if [[ "$stem" =~ $ADR_STEM_PATTERN ]]; then
            printf '[FAIL] (AC1-境界): 不適合 stem を誤って受理した: %s\n' "$stem"
            failed=$((failed + 1))
        else
            printf '[PASS] (AC1-境界): 不適合 stem を拒否する: %s\n' "$stem"
            passed=$((passed + 1))
        fi
    done
}

run_layer5_stem_pattern

echo
if [ "$failed" -eq 0 ]; then
    printf 'All tests passed: %d/%d\n' "$passed" "$total"
    exit 0
else
    printf 'Tests failed: %d passed / %d failed / %d total\n' "$passed" "$failed" "$total"
    exit 1
fi
