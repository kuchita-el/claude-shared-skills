#!/usr/bin/env bash
# 固定題材集合の実行支援スクリプト（adr-scoping-cases.sh）のテストランナー
#
# scripts/fixtures/adr-scoping-cases/ 配下の fixture を題材集合ディレクトリとして
# 被テストスクリプトへ末尾引数で渡し、exit code と出力の部分一致をアサートする。
# fixture は配布物外に置き、配布物内のスクリプトは fixture のパスを一切知らない
# （参照方向は配布物外 → 配布物内の一方向である）。
#
# 使い方:
#   bash scripts/test-adr-scoping-cases.sh
#
# exit code:
#   0: 全アサーションが通った
#   1: いずれかのアサーションが落ちた
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/adr/scripts/adr-scoping-cases.sh"      # 配布物内（被テスト）
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures/adr-scoping-cases"      # 配布物外（fixture）

JUDGMENTS_DIR="$FIXTURES_DIR/judgments"
# 対象文書は prompt がパスを差し込むだけで中身を読まないため、リポジトリ内の安定した
# 実在ファイルであれば足りる。被テスト対象の判定手続き文書を指す必要は無い。
DOC="$REPO_ROOT/CLAUDE.md"
MISSING_DOC="$REPO_ROOT/この対象文書は存在しない.md"
MISSING_DIR="$FIXTURES_DIR/この題材集合ディレクトリは存在しない"

passed=0
failed=0

# ---------------------------------------------------------------- 判定の部品

# 被テストスクリプトを実行し、標準出力と標準エラーを合わせて $output に、
# exit code を $rc に置く。
run() {
    set +e
    output="$(bash "$SCRIPT" "$@" 2>&1)"
    rc=$?
    set -e
}

# 標準出力だけを $output に捕捉する（prompt が返すパスを取るために使う）。
run_stdout() {
    set +e
    output="$(bash "$SCRIPT" "$@" 2>/dev/null)"
    rc=$?
    set -e
}

# 1件のアサーションの結果を記録して出力する。$1 説明 / $2 合否(1/0) / $3 詳細
record() {
    local name="$1" ok="$2" detail="${3:-}"
    if [ "$ok" -eq 1 ]; then
        printf '[PASS] %s\n' "$name"
        passed=$((passed + 1))
    else
        printf '[FAIL] %s\n' "$name"
        [ -n "$detail" ] && printf '       %s\n' "$detail"
        failed=$((failed + 1))
    fi
}

# 文字列 $1 に $2 が含まれないことを検査する（含まれなければ 0 を返す）。
assert_not_contains() {
    case "$1" in
        *"$2"*) return 1 ;;
        *) return 0 ;;
    esac
}

# 直前の run の結果を判定する。$1 説明 / $2 期待 exit code / $3 以降 出力に含まれるべき文字列
assert_run() {
    local name="$1" want_rc="$2"
    shift 2
    local ok=1 detail="" p
    if [ "$rc" -ne "$want_rc" ]; then
        ok=0
        detail="exit code 期待 $want_rc / 実際 $rc"
    fi
    for p in "$@"; do
        case "$output" in
            *"$p"*) ;;
            *) ok=0; detail="${detail}${detail:+ / }出力に含まれない: $p" ;;
        esac
    done
    [ "$ok" -eq 1 ] || detail="$detail"$'\n       出力:\n'"$output"
    record "$name" "$ok" "$detail"
}

# 与えた文字列に部分文字列が含まれることだけを判定する。$1 説明 / $2 対象文字列 / $3 以降 含まれるべき文字列
assert_out() {
    local name="$1" text="$2"
    shift 2
    local ok=1 detail="" p
    for p in "$@"; do
        case "$text" in
            *"$p"*) ;;
            *) ok=0; detail="${detail}${detail:+ / }出力に含まれない: $p" ;;
        esac
    done
    [ "$ok" -eq 1 ] || detail="$detail"$'\n       出力:\n'"$text"
    record "$name" "$ok" "$detail"
}

# ---------------------------------------------------------------- validate 系

run validate "$FIXTURES_DIR/valid"
assert_run "01. validate valid → exit 0" 0

run validate "$FIXTURES_DIR/missing-id"
assert_run "02. validate missing-id → exit 1、CASE-A2 を列挙する" 1 "CASE-A2"

run validate "$FIXTURES_DIR/missing-origin"
assert_run "03. validate missing-origin → exit 1、CASE-A2 と由来の未記入を告げる" 1 "CASE-A2" "由来"

run validate "$FIXTURES_DIR/missing-asset-type"
assert_run "04. validate missing-asset-type → exit 1、CASE-A2 と資産種別の未記入を告げる" 1 "CASE-A2" "資産種別"

run validate "$FIXTURES_DIR/missing-carrier"
assert_run "05. validate missing-carrier → exit 1、CASE-A2 と担い方の未記入を告げる" 1 "CASE-A2" "担い方"

run validate "$FIXTURES_DIR/missing-layer"
assert_run "06. validate missing-layer → exit 1、CASE-A2 と3層の欠落を告げる" 1 "CASE-A2" "3層"

run validate "$FIXTURES_DIR/no-template"
assert_run "07. validate no-template → exit 0（prompt-template.md の欠落は validate では見ない）" 0

run validate
assert_run "08. validate（題材集合ディレクトリの省略）→ exit 2、使い方を示す" 2 "使い方"

run validate "$MISSING_DIR"
assert_run "09. validate（存在しない題材集合ディレクトリ）→ exit 2" 2

# 引数で渡した題材集合ディレクトリが検査対象になっている（本番の題材集合を見ていない）ことの検査。
# 同じサブコマンドが渡したディレクトリ次第で 0 と 1 に分かれることをもって切り替えの成立とみなす。
run validate "$FIXTURES_DIR/valid"
switch_valid_rc=$rc
run validate "$FIXTURES_DIR/missing-id"
switch_broken_rc=$rc
if [ "$switch_valid_rc" -eq 0 ] && [ "$switch_broken_rc" -eq 1 ]; then
    record "10. 題材集合ディレクトリの切り替えが効いている（valid で 0・missing-id で 1。本番の題材集合を見ていない）" 1
else
    record "10. 題材集合ディレクトリの切り替えが効いている（valid で 0・missing-id で 1。本番の題材集合を見ていない）" 0 \
        "valid=$switch_valid_rc / missing-id=$switch_broken_rc"
fi

# ---------------------------------------------------------------- prompt 系

run_stdout prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid"
prompt_path="$output"
prompt_rc=$rc
prompt_lines="$(printf '%s\n' "$prompt_path" | wc -l | tr -d ' ')"
if [ "$prompt_rc" -eq 0 ] && [ "$prompt_lines" -eq 1 ] && [ -f "$prompt_path" ]; then
    record "11. prompt valid CASE-A1 → exit 0、標準出力は実在するファイルのパス1行" 1
else
    record "11. prompt valid CASE-A1 → exit 0、標準出力は実在するファイルのパス1行" 0 \
        "rc=$prompt_rc / 行数=$prompt_lines / 出力=$prompt_path"
fi

prompt_body=""
[ -f "$prompt_path" ] && prompt_body="$(cat "$prompt_path")"

assert_out "12. 組み立てたプロンプトに CASE-A1 の題材文が含まれる" "$prompt_body" "コミットを止める"

# 期待帰結層（expectations.tsv 由来の文字列）と他題材がプロンプトへ漏れていないこと。
leak_ok=1
leak_detail=""
for needle in "期待_" "改訂前から在る" "導出すべきもの" "NONE" "fixture（正常系）" "散文で述べているだけ"; do
    if ! assert_not_contains "$prompt_body" "$needle"; then
        leak_ok=0
        leak_detail="${leak_detail}${leak_detail:+ / }漏れている: $needle"
    fi
done
record "13. 組み立てたプロンプトに期待帰結層・他題材に由来する文字列が含まれない" "$leak_ok" "$leak_detail"

[ -n "$prompt_path" ] && [ -f "$prompt_path" ] && rm -f "$prompt_path"

run prompt "$DOC" CASE-ZZ "$FIXTURES_DIR/valid"
assert_run "14. prompt（題材集合に無い題材ID）→ exit 1、既知の題材IDを列挙する" 1 "CASE-A1"

run prompt "$MISSING_DOC" CASE-A1 "$FIXTURES_DIR/valid"
assert_run "15. prompt（存在しない対象文書）→ exit 2" 2

run prompt "$DOC" CASE-A1
assert_run "16. prompt（題材集合ディレクトリの省略）→ exit 2、使い方を示す" 2 "使い方"

run prompt "$DOC" CASE-A1 "$FIXTURES_DIR/no-template"
assert_run "17. prompt no-template → exit 2、prompt-template.md を欠けているファイルとして告げる" 2 "prompt-template.md"

# ---------------------------------------------------------------- report 系

run report "$JUDGMENTS_DIR/valid-judgments.tsv" "$FIXTURES_DIR/valid"
report_output="$output"
assert_run "18. report valid-judgments.tsv valid → exit 0" 0

assert_out "19. report 出力がセル単位の試行間一致件数を含む" "$report_output" \
    "試行 1 と 試行 2: 一致 7 / 8 セル (87.5%)"

assert_out "20. report 出力が項目別一致率を4項目分含む" "$report_output" \
    "項目1: 一致 2 / 2 (100.0%)" \
    "項目2: 一致 2 / 2 (100.0%)" \
    "項目3: 一致 1 / 2 (50.0%)" \
    "項目4: 一致 2 / 2 (100.0%)"

assert_out "21. report 出力が各項目の1点率（周辺分布）を試行ごとに含む" "$report_output" \
    "== 各項目の1点率（周辺分布。試行ごと） ==" \
    "試行 1:  項目1 50.0% (1/2)  項目2 50.0% (1/2)  項目3 50.0% (1/2)  項目4 50.0% (1/2)" \
    "試行 2:  項目1 50.0% (1/2)  項目2 50.0% (1/2)  項目3 0.0% (0/2)  項目4 50.0% (1/2)"

assert_out "22. report 出力が期待帰結との差として CASE-A2 の項目3 の差を含む" "$report_output" \
    "CASE-A2 試行2 項目3: 期待 1 / 判定 0"

run report "$JUDGMENTS_DIR/unknown-id-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "23. report unknown-id-judgments.tsv → exit 1、CASE-ZZ を列挙する" 1 "CASE-ZZ"

run report "$JUDGMENTS_DIR/missing-case-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "24. report missing-case-judgments.tsv → exit 1、未カバー題材 CASE-A2 を列挙する" 1 "CASE-A2" "未カバー"

run report "$JUDGMENTS_DIR/この判定記録は存在しない.tsv" "$FIXTURES_DIR/valid"
assert_run "25. report（存在しない判定記録TSV）→ exit 2" 2

run report "$JUDGMENTS_DIR/valid-judgments.tsv"
assert_run "26. report（題材集合ディレクトリの省略）→ exit 2" 2

# ---------------------------------------------------------------- サブコマンド

run
assert_run "27. サブコマンド無し → exit 2、使い方を示す" 2 "使い方"

run 存在しないサブコマンド
assert_run "28. 不明なサブコマンド → exit 2" 2

# ---------------------------------------------------------------- 集計

total=$((passed + failed))
echo
if [ "$failed" -eq 0 ]; then
    printf '全アサーション通過: 合格 %d / 失敗 %d / 総数 %d\n' "$passed" "$failed" "$total"
    exit 0
else
    printf 'アサーション失敗あり: 合格 %d / 失敗 %d / 総数 %d\n' "$passed" "$failed" "$total"
    exit 1
fi
