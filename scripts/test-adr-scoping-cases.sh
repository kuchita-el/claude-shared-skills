#!/usr/bin/env bash
# 固定題材集合の実行支援スクリプト（adr-scoping-cases.sh）のテストランナー
#
# scripts/fixtures/adr-scoping-cases/ 配下の fixture を題材集合ディレクトリとして
# 被テストスクリプトへ末尾引数で渡し、exit code と出力の部分一致をアサートする。
#
# 【配置について】テストランナーと fixture を配布物外（scripts/）へ置き、被テストの
# 検査器だけを配布物内（plugins/adr/scripts/）へ置く。これは意図した配置である。
# 参照方向を「配布物外のテスト → 配布物内の検査器」の一方向に固定し、配布物側が
# fixture のパスを一切知らない状態を保つためであり、配布物に検査用データを
# 同梱しないための境界でもある。
#
# 同ディレクトリの他の同梱スクリプト（lint-adr.sh / next-adr-id.sh）は現在テストと
# fixture を配布物内へ持っているが、これらを本配置へ追随させる作業は #623 で追跡している。
# したがって現状の非対称は移行の途中であり、本スクリプトの側を配布物内へ寄せて解消しない。
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

# 診断行のうち $1 に一致する行から、各行の先頭に現れる題材ID を出現順に連ねて返す。
# 走査順の検査は部分一致では代替できない（含まれてはいるが並びだけが違う退行を通す）ため、
# 並びそのものを1本の文字列へ畳んで突き合わせる。
first_case_ids() {
    printf '%s\n' "$2" | awk -v pat="$1" '
        $0 ~ pat && match($0, /CASE-[A-Z0-9]+/) { out = out (out == "" ? "" : " ") substr($0, RSTART, RLENGTH) }
        END { print out }
    '
}

# 診断の並びが期待どおりであることを判定する。
# $1 説明 / $2 対象文字列 / $3 診断行を絞る正規表現 / $4 期待する題材IDの並び
assert_case_id_order() {
    local name="$1" text="$2" pat="$3" want="$4" got
    got="$(first_case_ids "$pat" "$text")"
    if [ "$got" = "$want" ]; then
        record "$name" 1
    else
        record "$name" 0 "並び 期待 [$want] / 実際 [$got]"
    fi
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
assert_run "02. validate missing-id → exit 1、CASE-A2 の対応行が無いことを診断として告げ、違反1件と数える" 1 \
    "expectations.tsv に対応する行が無い題材: CASE-A2" "違反 1 件"

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

# exit code だけを見ると、存在検査を落としても後続のファイル存在検査が別理由で
# exit 2 を返すため検査が通ってしまう。理由を名指しする診断文まで押さえる。
run validate "$MISSING_DIR"
assert_run "09. validate（存在しない題材集合ディレクトリ）→ exit 2、ディレクトリが存在しないことを理由として告げる" 2 \
    "題材集合ディレクトリが存在しない"

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

# 題材IDの存在検査を正規表現一致で書くと、`CASE-A.` のような入力が既知の題材へ当たって
# 存在検査を通過する。exit code だけでは後段の「題材文が空である」と区別できないため、
# 診断が「題材ID が題材集合に無い」であることまで押さえる。
run prompt "$DOC" 'CASE-A.' "$FIXTURES_DIR/valid"
assert_run "14a. prompt（題材IDに正規表現メタ文字を含む）→ exit 1、題材IDが題材集合に無いことを告げる（別の診断へ化けない）" 1 \
    "題材ID が題材集合に無い: CASE-A."

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

# 項目1〜4 以外の出力層（カバレッジ件数・合計列・行き先列・差の総数）も押さえる。
# 項目別の一致率だけを見ていると、これらを壊しても検査が通ってしまう。
assert_out "22a. report 出力がカバレッジ件数行を含む" "$report_output" \
    "題材 2 件中 2 件を記録が覆う"

assert_out "22b. report 出力が合計列・行き先列の試行間一致率を含む" "$report_output" \
    "合計: 一致 1 / 2 (50.0%)" \
    "行き先: 一致 2 / 2 (100.0%)"

assert_out "22c. report 出力が期待帰結との差として合計列の差と差の総数を含む" "$report_output" \
    "CASE-A2 試行2 合計: 期待 4 / 判定 3" \
    "差 2 件"

run report "$JUDGMENTS_DIR/unknown-id-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "23. report unknown-id-judgments.tsv → exit 1、CASE-ZZ を列挙する" 1 "CASE-ZZ"

run report "$JUDGMENTS_DIR/missing-case-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "24. report missing-case-judgments.tsv → exit 1、未カバー題材 CASE-A2 を列挙する" 1 "CASE-A2" "未カバー"

run report "$JUDGMENTS_DIR/この判定記録は存在しない.tsv" "$FIXTURES_DIR/valid"
assert_run "25. report（存在しない判定記録TSV）→ exit 2、判定記録TSV が存在しないことを理由として告げる" 2 \
    "判定記録TSV が存在しない"

run report "$JUDGMENTS_DIR/valid-judgments.tsv"
assert_run "26. report（題材集合ディレクトリの省略）→ exit 2、引数の個数が合わないことを理由として告げる" 2 \
    "report は引数を2つ取る"

# ---------------------------------------------------------------- サブコマンド

run
assert_run "27. サブコマンド無し → exit 2、使い方を示す" 2 "使い方"

run 存在しないサブコマンド
assert_run "28. 不明なサブコマンド → exit 2、受け取ったサブコマンド名を添えて理由を告げる" 2 \
    "サブコマンドが不明: 存在しないサブコマンド"

# ---------------------------------------------------------------- 検査の取りこぼし補い
#
# 実装済みでありながらアサーションを持たなかった検査を押さえる。
# 各 fixture は valid/ の複製から1箇所だけを壊したものである。

run validate "$FIXTURES_DIR/duplicate-id"
assert_run "29. validate duplicate-id → exit 1、題材IDの重複を CASE-A1 として告げる" 1 "重複" "CASE-A1"

run validate "$FIXTURES_DIR/total-mismatch"
assert_run "30. validate total-mismatch → exit 1、CASE-A2 の期待_合計が項目1〜4 の和と一致しないことを告げる" 1 \
    "CASE-A2" "和と一致しない"

run validate "$FIXTURES_DIR/unknown-partner"
assert_run "31. validate unknown-partner → exit 1、どの題材の対の相手IDが題材集合に無いのかを告げる" 1 \
    "CASE-A1: 対の相手ID が題材集合に無い (CASE-ZZ)"

run validate "$FIXTURES_DIR/asymmetric-pair"
assert_run "32. validate asymmetric-pair → exit 1、対の相手IDが相互参照になっていないことを告げる" 1 "相互参照"

run validate "$FIXTURES_DIR/invalid-origin"
assert_run "33. validate invalid-origin → exit 1、CASE-A2 の由来が語彙外であることを告げる" 1 "CASE-A2" "語彙外"

run validate "$FIXTURES_DIR/invalid-carrier"
assert_run "34. validate invalid-carrier → exit 1、CASE-A2 の規範の担い方が語彙外であることを告げる" 1 "CASE-A2" "語彙外"

run validate "$FIXTURES_DIR/no-header"
assert_run "35. validate no-header → exit 1、expectations.tsv のヘッダ行の欠落を告げる" 1 "ヘッダ行"

run report "$JUDGMENTS_DIR/duplicate-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "36. report duplicate-judgments.tsv → exit 1、CASE-A1 の重複した行を告げる" 1 "重複" "CASE-A1"

# commit 列にプレースホルダが残ったまま提出された記録を素通りさせない。
# 列を持たない記録（他の judgments fixture は14列）は検査対象外であることも同時に押さえる。
run report "$JUDGMENTS_DIR/unresolved-commit-judgments.tsv" "$FIXTURES_DIR/valid"
assert_run "36a. report（commit 列にプレースホルダが残る記録）→ exit 1、14列目・15列目それぞれを題材・試行・列名で名指しする" 1 \
    "CASE-A1 試行1 題材集合commit が短縮ハッシュでない: 未コミット" \
    "CASE-A2 試行1 対象文書commit が短縮ハッシュでない: 未コミット" \
    "未確定 2 件"

# ここから2件は、レビューで見つかり修正済みの不具合に対する回帰保護である。

# 題材が1件も無いとき、診断を出さずに落ちてはならない。exit code だけでなく
# 診断文が出ることまで見ないと、無言で落ちる状態へ戻っても検査が通ってしまう。
run validate "$FIXTURES_DIR/no-case-heading"
assert_run "37. validate no-case-heading → exit 1、題材が1件も無いことを診断として告げる（無言で落ちない）" 1 \
    "題材が1件も無い"

# メタ行を題材文ブロックの内側へ書いた場合、必須フィールド検査を通してはならない。
# あわせて、メタ行が正しく外側にある valid では判定側へ渡るプロンプトにメタ行が
# 現れないことを確かめ、メタ行と題材文の境界を両側から押さえる。
run validate "$FIXTURES_DIR/meta-inside-body"
meta_ok=1
meta_detail=""
if [ "$rc" -ne 1 ]; then
    meta_ok=0
    meta_detail="validate の exit code 期待 1 / 実際 $rc"
fi
# 「内側にある」ことの告知だけでは、メタ行の抽出範囲が題材文の内側まで伸びる退行を
# 捕まえられない（本文からメタ行を拾えてしまうと未記入検査が素通りする）。
# 未記入検査が本文を見ていないことまで、違反の中身と件数で押さえる。
for needle in "メタ行が題材文ブロックの内側にある" "CASE-A1" \
    "判定対象の資産種別が未記入: CASE-A1" "規範の担い方が未記入: CASE-A1" "違反 3 件"; do
    case "$output" in
        *"$needle"*) ;;
        *) meta_ok=0; meta_detail="${meta_detail}${meta_detail:+ / }validate の出力に含まれない: $needle" ;;
    esac
done

run_stdout prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid"
meta_prompt_path="$output"
meta_prompt_body=""
if [ "$rc" -ne 0 ] || [ ! -f "$meta_prompt_path" ]; then
    meta_ok=0
    meta_detail="${meta_detail}${meta_detail:+ / }prompt が組み立てに失敗した (rc=$rc)"
else
    meta_prompt_body="$(cat "$meta_prompt_path")"
    rm -f "$meta_prompt_path"
fi
if ! assert_not_contains "$meta_prompt_body" "資産種別"; then
    meta_ok=0
    meta_detail="${meta_detail}${meta_detail:+ / }valid の prompt へメタ行が漏れている: 資産種別"
fi
record "38. validate meta-inside-body → exit 1、メタ行が題材文ブロックの内側にあることを CASE-A1 として告げる（あわせて valid の prompt にメタ行が漏れない）" \
    "$meta_ok" "$meta_detail"

# ---------------------------------------------------------------- 利用者入力の取り扱い
#
# 以下3件は、パス・環境・題材の大きさといった利用者側の入力によって
# 無言で誤った出力を出す／診断ゼロで落ちる欠陥に対する回帰保護である。

# 対象文書パスに `&` や `\` が含まれても、差し込み記号が出力へ再挿入されてはならない。
# awk の gsub は置換文字列中の `&` をマッチ文字列へ展開し、`-v` は代入値のエスケープ列を
# 解釈する。いずれも素朴に書くと exit 0 のまま誤った内容のプロンプトが出来上がる。
AMP_DIR="$(mktemp -d -t adr-scoping-case-amp.XXXXXX)/di&r\\x"
mkdir -p "$AMP_DIR"
cp "$DOC" "$AMP_DIR/doc.md"
run_stdout prompt "$AMP_DIR/doc.md" CASE-A1 "$FIXTURES_DIR/valid"
amp_ok=1
amp_detail=""
amp_path="$output"
if [ "$rc" -ne 0 ] || [ ! -f "$amp_path" ]; then
    amp_ok=0
    amp_detail="prompt が組み立てに失敗した (rc=$rc)"
else
    amp_body="$(cat "$amp_path")"
    rm -f "$amp_path"
    if ! assert_not_contains "$amp_body" "{{対象文書パス}}"; then
        amp_ok=0
        amp_detail="差し込み記号が出力へ再挿入されている（gsub の & 展開）"
    fi
    case "$amp_body" in
        *"$AMP_DIR/doc.md"*) ;;
        *) amp_ok=0; amp_detail="${amp_detail}${amp_detail:+ / }対象文書パスがそのまま差し込まれていない" ;;
    esac
fi
record "39. prompt（対象文書パスに & と \\ を含む）→ 差し込み記号を再挿入せず、パスをそのまま載せる" "$amp_ok" "$amp_detail"
rm -rf "$(dirname "$AMP_DIR")"

# $TMPDIR に単一引用符や `\` が含まれても、後始末の trap が壊れず、
# 題材文が空のままのプロンプトが出来上がってもならない。
# 前者は EXIT trap のクォート破壊で exit 2、後者は awk -v のエスケープ解釈で
# 一時ファイルのパスが壊れ、題材文の差し込みが1行も回らないことによる。
# 同じ異常な $TMPDIR を prompt だけでなく validate / report へも流す。同型の欠陥は
# 一時ファイルと awk を使うサブコマンドすべてに現れうるため、片方だけ試すと取りこぼす。
quote_n=0
for weird in "it's" 'back\slash'; do
    quote_n=$((quote_n + 1))
    quote_label="$([ "$quote_n" -eq 1 ] && printf '40a' || printf '40b')"
    QUOTE_TMPDIR="$(mktemp -d -t adr-scoping-case-q.XXXXXX)/$weird"
    mkdir -p "$QUOTE_TMPDIR"
    set +e
    quote_path="$(TMPDIR="$QUOTE_TMPDIR" bash "$SCRIPT" prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid" 2>"$QUOTE_TMPDIR/err")"
    quote_rc=$?
    set -e
    quote_stderr="$(cat "$QUOTE_TMPDIR/err")"
    quote_ok=1
    quote_detail=""
    if [ "$quote_rc" -ne 0 ] || [ -n "$quote_stderr" ]; then
        quote_ok=0
        quote_detail="prompt: rc=$quote_rc / stderr=$quote_stderr"
    elif [ ! -f "$quote_path" ]; then
        quote_ok=0
        quote_detail="prompt: 出力ファイルが無い: $quote_path"
    else
        case "$(cat "$quote_path")" in
            *"コミットを止める"*) ;;
            *) quote_ok=0; quote_detail="prompt: 題材文が差し込まれていない（空のプロンプト）" ;;
        esac
        rm -f "$quote_path"
    fi

    # validate と report も同じ $TMPDIR で通す。report は期待帰結との差まで出ること
    # （一時ファイルを読めていれば差2件が出る）を見て、無言の結論反転を捕まえる。
    set +e
    qv_out="$(TMPDIR="$QUOTE_TMPDIR" bash "$SCRIPT" validate "$FIXTURES_DIR/valid" 2>&1)"
    qv_rc=$?
    qr_out="$(TMPDIR="$QUOTE_TMPDIR" bash "$SCRIPT" report "$JUDGMENTS_DIR/valid-judgments.tsv" "$FIXTURES_DIR/valid" 2>&1)"
    qr_rc=$?
    set -e
    [ "$qv_rc" -eq 0 ] || { quote_ok=0; quote_detail="${quote_detail}${quote_detail:+ / }validate: rc=$qv_rc / $qv_out"; }
    [ "$qr_rc" -eq 0 ] || { quote_ok=0; quote_detail="${quote_detail}${quote_detail:+ / }report: rc=$qr_rc / $qr_out"; }
    case "$qr_out" in
        *"差 2 件"*) ;;
        *) quote_ok=0; quote_detail="${quote_detail}${quote_detail:+ / }report: 期待帰結との差が出ていない（結論が無言で反転している）" ;;
    esac

    record "$quote_label. prompt/validate/report（\$TMPDIR に $weird を含む）→ exit 0、trap が壊れず題材文・期待帰結も読める" "$quote_ok" "$quote_detail"
    rm -rf "$(dirname "$QUOTE_TMPDIR")"
done

# 題材集合ディレクトリのパスそのものに `&` と `\` が含まれる場合。
# awk -v のエスケープ解釈で期待帰結ファイルを読めないと、report は無言で
# 「差は無い」へ倒れる（診断ゼロで結論だけが反転する経路）。
WEIRD_CASE_DIR="$(mktemp -d -t adr-scoping-case-wd.XXXXXX)/di&r\\x"
mkdir -p "$WEIRD_CASE_DIR"
cp "$FIXTURES_DIR/valid/cases.md" "$FIXTURES_DIR/valid/expectations.tsv" "$FIXTURES_DIR/valid/prompt-template.md" "$WEIRD_CASE_DIR/"
run report "$JUDGMENTS_DIR/valid-judgments.tsv" "$WEIRD_CASE_DIR"
assert_run "40c. report（題材集合ディレクトリのパスに & と \\ を含む）→ 期待帰結を読み、差2件をそのまま出す" 0 \
    "CASE-A2 試行2 項目3: 期待 1 / 判定 0" "差 2 件"
run validate "$WEIRD_CASE_DIR"
assert_run "40d. validate（題材集合ディレクトリのパスに & と \\ を含む）→ exit 0" 0 "題材集合の検査に通った"
rm -rf "$(dirname "$WEIRD_CASE_DIR")"

# 題材文ブロックの内側にメタ行があり、かつ本文がパイプ長を超える場合。
# 内側検査をパイプで書くと、grep が最初のマッチで閉じて書き手が SIGPIPE を受け、
# 条件式の文脈では set -e が発火しないまま「違反なし」へ倒れて exit 0 で素通りする。
# アサーション38 はメタ行領域側しか膨らませないため、この経路は別に押さえる。
run validate "$FIXTURES_DIR/meta-inside-large-body"
assert_run "38a. validate（メタ行が内側にあり題材文本文がパイプ長を超える）→ exit 1、内側にあることを告げる" 1 \
    "メタ行が題材文ブロックの内側にある" "CASE-A1"

# 題材文が空の題材を、validate も prompt も通してはならない。
run validate "$FIXTURES_DIR/empty-body"
assert_run "38b. validate（題材文が空）→ exit 1、3層のうち題材文が欠けていることを告げる" 1 \
    "3層のうち題材文が欠けている" "CASE-A1"

run prompt "$DOC" CASE-A1 "$FIXTURES_DIR/empty-body"
assert_run "38c. prompt（題材文が空）→ exit 1、題材文が空であることを告げる" 1 "題材文が空である"

# 差し込み記号を書き落とした雛形は、題材文の無いプロンプトを exit 0 で生む。
# 検査を validate だけに置くと、成果物を生む側（prompt は validate を呼ばない）が
# 塞がらないため、同じ雛形を両方の経路へ通す。
run validate "$FIXTURES_DIR/template-missing-marker"
assert_run "38d. validate（雛形が {{題材文}} を欠く）→ exit 1、欠けている差し込み記号を名指しする" 1 \
    "prompt-template.md に差し込み記号が無い: {{題材文}}"

run prompt "$DOC" CASE-A1 "$FIXTURES_DIR/template-missing-marker"
assert_run "38e. prompt（雛形が {{題材文}} を欠く）→ exit 1、欠けている差し込み記号を名指しする（題材文の無いプロンプトを生まない）" 1 \
    "prompt-template.md に差し込み記号が無い" "{{題材文}}"

# 期待帰結を1件も読めないまま集計を続けると「差は無い」と出て結論が無言で反転する。
# 診断が出ることだけを見ても足りない。awk の exit は BEGIN で呼んでも END を飛ばさないため、
# 診断の直後に集計本文が最後まで印字される状態を通してしまう。本文が出ないことまで見る。
NOEXP_DIR="$(mktemp -d -t adr-scoping-case-ne.XXXXXX)"
cp "$FIXTURES_DIR/valid/cases.md" "$FIXTURES_DIR/valid/prompt-template.md" "$NOEXP_DIR/"
printf '# 注記行だけで期待帰結の行を持たない\n' > "$NOEXP_DIR/expectations.tsv"
run report "$JUDGMENTS_DIR/valid-judgments.tsv" "$NOEXP_DIR"
noexp_ok=1
noexp_detail=""
[ "$rc" -eq 1 ] || { noexp_ok=0; noexp_detail="exit code 期待 1 / 実際 $rc"; }
case "$output" in
    *"期待帰結を1件も読めなかった"*) ;;
    *) noexp_ok=0; noexp_detail="${noexp_detail}${noexp_detail:+ / }診断が出ていない" ;;
esac
for needle in "差は無い" "== カバレッジ ==" "== 期待帰結との差 =="; do
    if ! assert_not_contains "$output" "$needle"; then
        noexp_ok=0
        noexp_detail="${noexp_detail}${noexp_detail:+ / }集計本文が印字されている: $needle"
    fi
done
record "40e. report（期待帰結を1件も読めない）→ 診断を出して落ち、集計本文を1行も印字しない" "$noexp_ok" "$noexp_detail"

# 題材が0件の題材集合では、カバレッジ側が別理由で落とすこともない。
# 期待帰結の未読を BEGIN の exit だけで扱っていると、この組み合わせが rc=0 で素通りする。
NOEXP0_DIR="$(mktemp -d -t adr-scoping-case-n0.XXXXXX)"
printf '# 題材を1件も持たない cases.md\n' > "$NOEXP0_DIR/cases.md"
cp "$FIXTURES_DIR/valid/prompt-template.md" "$NOEXP0_DIR/"
printf '# 注記行だけで期待帰結の行を持たない\n' > "$NOEXP0_DIR/expectations.tsv"
run report "$JUDGMENTS_DIR/valid-judgments.tsv" "$NOEXP0_DIR"
noexp0_ok=1
noexp0_detail=""
[ "$rc" -ne 0 ] || { noexp0_ok=0; noexp0_detail="exit code 0 で素通りした"; }
if ! assert_not_contains "$output" "差は無い"; then
    noexp0_ok=0
    noexp0_detail="${noexp0_detail}${noexp0_detail:+ / }「差は無い」が印字されている"
fi
record "40f. report（期待帰結も題材も0件）→ 素通りせず、「差は無い」も印字しない" "$noexp0_ok" "$noexp0_detail"
rm -rf "$NOEXP_DIR" "$NOEXP0_DIR"

# ---------------------------------------------------------------- 診断の走査順
#
# 連想配列を素朴に `for (k in arr)` で走査すると、診断の並びが awk の実装依存になる。
# 出力は集計レポートへ貼り込むため、記載・記録の出現順に固定されていなければならない。
# 部分一致のアサーションでは「含まれてはいるが並びだけが違う」退行を通してしまうため、
# 以下4件は並びそのものを突き合わせる。fixture の題材IDは、素朴な走査だと gawk・mawk の
# いずれでも出現順と異なる並びになる組み合わせを選んである。
SCAN_ORDER_IDS="CASE-A1 CASE-ZZ CASE-M3 CASE-B2 CASE-Q9 CASE-D4"

run report "$JUDGMENTS_DIR/unknown-id-multi-judgments.tsv" "$FIXTURES_DIR/valid"
assert_case_id_order "43a. report（未知の題材IDが複数）→ 診断が記録の出現順で並ぶ" "$output" \
    "題材集合に無い題材IDの行" "CASE-ZZ CASE-M3 CASE-B2 CASE-Q9 CASE-D4"

run report "$JUDGMENTS_DIR/scan-order-dupe-judgments.tsv" "$FIXTURES_DIR/scan-order"
assert_case_id_order "43b. report（重複した行が複数）→ 診断が記録の出現順で並ぶ" "$output" \
    "重複した行" "$SCAN_ORDER_IDS"

run report "$JUDGMENTS_DIR/scan-order-badcommit-judgments.tsv" "$FIXTURES_DIR/scan-order"
assert_case_id_order "43c. report（commit 列の未確定が複数）→ 診断が記録の出現順で並ぶ" "$output" \
    "短縮ハッシュでない" "$SCAN_ORDER_IDS"

run validate "$FIXTURES_DIR/scan-order"
assert_case_id_order "43d. validate（対の相手IDが題材集合に無い題材が複数）→ 診断が記載の出現順で並ぶ" "$output" \
    "対の相手ID が題材集合に無い" "$SCAN_ORDER_IDS"

# メタ行が多い題材でも、パイプの早期終了による SIGPIPE で診断ゼロのまま落ちてはならない。
# 読み手を先に閉じても書き手を先に閉じても pipefail + set -e で rc=141 になるため、
# パイプ長より十分大きいメタ行を与えて両側が最後まで生きることを確かめる。
BIG_DIR="$(mktemp -d -t adr-scoping-case-big.XXXXXX)"
cp "$FIXTURES_DIR/valid/expectations.tsv" "$FIXTURES_DIR/valid/prompt-template.md" "$BIG_DIR/"
awk '
    /^### 題材文$/ && !done {
        done = 1
        for (i = 0; i < 1500; i++) {
            line = "- 資産種別: "
            for (j = 0; j < 10; j++) line = line "0123456789"
            print line
        }
    }
    { print }
' "$FIXTURES_DIR/valid/cases.md" > "$BIG_DIR/cases.md"
run validate "$BIG_DIR"
assert_run "41. validate（メタ行がパイプ長を超える題材）→ 診断ゼロの異常終了をせず検査を完了する" 0 \
    "題材集合の検査に通った"
rm -rf "$BIG_DIR"

# ---------------------------------------------------------------- 配布物の非依存性
#
# 配布物内のスクリプトが配布元リポジトリ固有の名前を知らないことを機械検査する。
# 検査器は題材集合ディレクトリと対象文書パスを引数でのみ受け取る建て付けであり、
# 固有名がコードパスへ現れた時点でその建て付けが崩れる。
# 走査は既知の固有名のリストであり、リストに無い新種は検出できない。
repo_specific_hits="$(grep -nE 'docs/|plugins/|scripts/|\.claude/|adr-scoping\.md|claude-shared-skills|manage-adr' "$SCRIPT" || true)"
if [ -z "$repo_specific_hits" ]; then
    record "42. 配布物内のスクリプトが配布元リポジトリ固有の名前（ディレクトリ構成・リポジトリ名・対象文書名）を含まない" 1
else
    record "42. 配布物内のスクリプトが配布元リポジトリ固有の名前（ディレクトリ構成・リポジトリ名・対象文書名）を含まない" 0 \
        "検出:"$'\n'"$repo_specific_hits"
fi

# 同じ原則は配布物のドキュメントにも及ぶ。配布先の利用者から見て Issue 番号は解決できない
# 参照であり、追跡の記録は配布物外（ADR の関連Issue 行・配布元の開発ドキュメント・
# 本テストランナー）へ置く。アサーション42 の走査対象はスクリプト本体のみで、
# 実際にこの型の混入を README で1件取りこぼしたため、走査を配布物全体へ広げる。
issue_ref_hits="$(grep -rnE '(^|[^A-Za-z0-9_])#[0-9]{2,}' "$REPO_ROOT/plugins/adr" \
    --include='*.md' --include='*.sh' --include='*.json' || true)"
if [ -z "$issue_ref_hits" ]; then
    record "44. 配布物（plugins/adr 配下）が配布元リポジトリの Issue 番号を含まない" 1
else
    record "44. 配布物（plugins/adr 配下）が配布元リポジトリの Issue 番号を含まない" 0 \
        "検出:"$'\n'"$issue_ref_hits"
fi

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
