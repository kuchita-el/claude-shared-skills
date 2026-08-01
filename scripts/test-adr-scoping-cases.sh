#!/usr/bin/env bash
# 固定題材集合の実行支援スクリプト（adr-scoping-cases.sh）のテストランナー
#
# scripts/fixtures/adr-scoping-cases/ 配下の fixture を題材集合ディレクトリとして
# 被テストスクリプトへ末尾引数で渡し、exit code と出力の部分一致をアサートする。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
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

# PATH の先頭へ差し込む awk の代役を作る。$AWK_SHIM_FAIL_AT 回目の呼び出しだけを
# 異常終了（awk の fatal と同じ exit 2）させ、それ以外は本物の awk へ委譲する。
# 「awk が落ちたとき」の経路を決定的に踏ませるために使う。
#
# **呼び出しの序数に依存する**。被テスト側の awk 呼び出しが増減すると、同じ
# $AWK_SHIM_FAIL_AT が別の呼び出しを落とすことになる。現状は report が1本
# （集計本体）、prompt が2本（1本目 extract_case_text・2本目 雛形の組み立て）。
# ずれても各アサーションはメッセージまで見ているため静かには壊れないが、
# awk 呼び出しを足したときは序数を見直すこと。
make_awk_shim() {
    local shim_dir="$1" real_awk
    real_awk="$(command -v awk)"
    mkdir -p "$shim_dir"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'n=$(cat "$AWK_SHIM_COUNT" 2>/dev/null || echo 0)\n'
        printf 'n=$((n + 1)); printf %%s "$n" > "$AWK_SHIM_COUNT"\n'
        printf 'if [ "$n" -eq "$AWK_SHIM_FAIL_AT" ]; then printf "awk shim: 強制失敗\\n" >&2; exit 2; fi\n'
        printf 'exec %s "$@"\n' "$real_awk"
    } > "$shim_dir/awk"
    chmod +x "$shim_dir/awk"
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
# awk の終了状態を一律で畳むと、末尾のラベルが原因を取り違える（期待帰結を読めなかった
# のに「判定記録の集計に失敗した」＝既定の枝が出る）。打ち切りの理由がラベルにも表れる
# ことと、既定の枝へ落ちていないことの両方を見る。needle は現に printf される文字列で
# なければ空振りするので、`case "$rc"` のラベルを変えたときはここも合わせること。
case "$output" in
    *"期待帰結を読めなかったため集計を打ち切った"*) ;;
    *) noexp_ok=0; noexp_detail="${noexp_detail}${noexp_detail:+ / }打ち切りの理由がラベルに出ていない" ;;
esac
if ! assert_not_contains "$output" "判定記録の集計に失敗した"; then
    noexp_ok=0
    noexp_detail="${noexp_detail}${noexp_detail:+ / }ラベルが既定の枝（判定記録の集計に失敗した）へ落ちている"
fi
record "40e. report（期待帰結を1件も読めない）→ 診断とラベルの両方で理由を告げ、集計本文を1行も印字しない" "$noexp_ok" "$noexp_detail"

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

# prompt が成功した場合、$TMPDIR に残るのは呼び出し側へ返したプロンプト1件だけであること。
# 作業用の一時ファイルの後始末と、出力用ファイルを後始末の対象から外す位置の両方に効く
# （外し忘れると EXIT trap が返したファイルごと消し、外すのが早すぎると作業用が残る）。
# なお awk が落ちる経路での出力用ファイルの後始末は、決定的に起こせる引き金が無いため
# ここでは押さえられていない。
LEAK_TMPDIR="$(mktemp -d -t adr-scoping-case-leak.XXXXXX)"
set +e
leak_path="$(TMPDIR="$LEAK_TMPDIR" bash "$SCRIPT" prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid" 2>/dev/null)"
leak_rc=$?
set -e
leak_count="$(find "$LEAK_TMPDIR" -type f | wc -l | tr -d ' ')"
leak_ok=1
leak_detail=""
[ "$leak_rc" -eq 0 ] || { leak_ok=0; leak_detail="rc=$leak_rc"; }
[ -f "$leak_path" ] || { leak_ok=0; leak_detail="${leak_detail}${leak_detail:+ / }返したパスの実体が無い: $leak_path"; }
[ "$leak_count" -eq 1 ] || { leak_ok=0; leak_detail="${leak_detail}${leak_detail:+ / }\$TMPDIR に残ったファイルが $leak_count 件"; }
record "46. prompt 成功時、\$TMPDIR に残るのは返したプロンプト1件だけ（作業用の一時ファイルを残さず、返すファイルも消さない）" "$leak_ok" "$leak_detail"
rm -rf "$LEAK_TMPDIR"

# ---------------------------------------------------------------- 集計の異常終了と打ち切りの区別
#
# gawk・mawk とも fatal error では exit 2 を返す。打ち切りの番兵に 2 を使うと、
# 呼び出し側が awk の異常終了を「期待帰結を読めなかった」と読み違え、無関係な
# expectations.tsv のパスを名指しする。以下2件で、両経路が別の原因として出ることを見る。

# 判定記録TSV の可読性は、対象文書パスや題材集合ディレクトリと同じく引数の検査で押さえる。
UNREADABLE_J="$(mktemp -d -t adr-scoping-case-uj.XXXXXX)"
cp "$JUDGMENTS_DIR/valid-judgments.tsv" "$UNREADABLE_J/j.tsv"
chmod 000 "$UNREADABLE_J/j.tsv"
if [ -r "$UNREADABLE_J/j.tsv" ]; then
    record "47. report（判定記録TSV を読めない）→ exit 2、判定記録TSV を名指しする（期待帰結の側へ化けない）" 1 \
        "（chmod 000 でも読める環境のため未実行）"
else
    run report "$UNREADABLE_J/j.tsv" "$FIXTURES_DIR/valid"
    uj_ok=1
    uj_detail=""
    [ "$rc" -eq 2 ] || { uj_ok=0; uj_detail="exit code 期待 2 / 実際 $rc"; }
    case "$output" in
        *"判定記録TSV を読めない"*) ;;
        *) uj_ok=0; uj_detail="${uj_detail}${uj_detail:+ / }判定記録TSV を名指ししていない" ;;
    esac
    if ! assert_not_contains "$output" "期待帰結"; then
        uj_ok=0
        uj_detail="${uj_detail}${uj_detail:+ / }診断が期待帰結の側へ化けている"
    fi
    record "47. report（判定記録TSV を読めない）→ exit 2、判定記録TSV を名指しする（期待帰結の側へ化けない）" "$uj_ok" "$uj_detail"
fi
chmod 644 "$UNREADABLE_J/j.tsv"
rm -rf "$UNREADABLE_J"

# 集計そのものが異常終了した場合（awk の fatal = exit 2）。打ち切りの番兵と衝突していると、
# 期待帰結を読めていたにもかかわらず「期待帰結を読めなかった」と表示される。
AWK_SHIM_DIR="$(mktemp -d -t adr-scoping-case-shim.XXXXXX)"
make_awk_shim "$AWK_SHIM_DIR"
set +e
shim_out="$(AWK_SHIM_COUNT="$AWK_SHIM_DIR/count" AWK_SHIM_FAIL_AT=1 PATH="$AWK_SHIM_DIR:$PATH" \
    bash "$SCRIPT" report "$JUDGMENTS_DIR/valid-judgments.tsv" "$FIXTURES_DIR/valid" 2>&1)"
shim_rc=$?
set -e
shim_ok=1
shim_detail=""
[ "$shim_rc" -eq 1 ] || { shim_ok=0; shim_detail="exit code 期待 1 / 実際 $shim_rc"; }
case "$shim_out" in
    *"判定記録の集計に失敗した"*) ;;
    *) shim_ok=0; shim_detail="${shim_detail}${shim_detail:+ / }集計の失敗として告げていない" ;;
esac
for needle in "期待帰結を読めなかった" "expectations.tsv"; do
    if ! assert_not_contains "$shim_out" "$needle"; then
        shim_ok=0
        shim_detail="${shim_detail}${shim_detail:+ / }打ち切り経路と取り違えている: $needle"
    fi
done
record "48. report（集計そのものが異常終了）→ 判定記録TSV を名指しし、期待帰結の打ち切りと取り違えない" "$shim_ok" "$shim_detail"

# prompt の組み立ての awk が異常終了した場合。診断ゼロで抜けると、中身の欠けた
# 一時ファイルだけが $TMPDIR に残る。原因を名指しし、かつ残さないことを見る。
SHIM_TMPDIR="$(mktemp -d -t adr-scoping-case-st.XXXXXX)"
: > "$AWK_SHIM_DIR/count"
set +e
shim_prompt_out="$(AWK_SHIM_COUNT="$AWK_SHIM_DIR/count" AWK_SHIM_FAIL_AT=2 TMPDIR="$SHIM_TMPDIR" \
    PATH="$AWK_SHIM_DIR:$PATH" bash "$SCRIPT" prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid" 2>&1)"
shim_prompt_rc=$?
set -e
shim_prompt_left="$(find "$SHIM_TMPDIR" -type f | wc -l | tr -d ' ')"
sp_ok=1
sp_detail=""
[ "$shim_prompt_rc" -eq 1 ] || { sp_ok=0; sp_detail="exit code 期待 1 / 実際 $shim_prompt_rc"; }
case "$shim_prompt_out" in
    *"プロンプトの組み立てに失敗した"*) ;;
    *) sp_ok=0; sp_detail="${sp_detail}${sp_detail:+ / }スクリプト自身の診断が出ていない" ;;
esac
[ "$shim_prompt_left" -eq 0 ] || { sp_ok=0; sp_detail="${sp_detail}${sp_detail:+ / }\$TMPDIR に $shim_prompt_left 件残った"; }
record "49. prompt（組み立ての処理が異常終了）→ 原因を名指しして落ち、一時ファイルを残さない" "$sp_ok" "$sp_detail"
rm -rf "$SHIM_TMPDIR" "$AWK_SHIM_DIR"

# 組み立ての awk は、題材文の一時ファイルを1行も読めなかったときに自前で診断を出して
# 番兵 3 で落ちる。呼び出し側の `||` ハンドラがこれを awk の異常終了と区別できないと、
# 原因を名指しした1行目の後ろへ「異常終了した」と述べる2行目が積まれ、無関係な
# prompt-template.md が名指しされる（cmd_report で番兵 3 を入れて解いたのと同型）。
#
# 一時ファイルを書き込み専用（200）で先に作らせることで、書き込みは通り読み込みだけが
# 落ちる状況を決定的に作る。mktemp の代役は序数ではなく雛形の名前で分岐させる。
MKTEMP_SHIM_DIR="$(mktemp -d -t adr-scoping-case-ms.XXXXXX)"
WRITEONLY_BODY="$MKTEMP_SHIM_DIR/body-writeonly"
: > "$WRITEONLY_BODY"
chmod 200 "$WRITEONLY_BODY"
if [ -r "$WRITEONLY_BODY" ]; then
    record "50. prompt（題材文の一時ファイルを読めない）→ 原因を1度だけ名指しし、雛形の異常終了へ化けない" 1 \
        "（chmod 200 でも読める環境のため未実行）"
else
    {
        printf '#!/usr/bin/env bash\n'
        printf 'for a in "$@"; do case "$a" in *adr-scoping-case-body*) printf %%s\\\\n "$WRITEONLY_BODY"; exit 0 ;; esac; done\n'
        printf 'exec %s "$@"\n' "$(command -v mktemp)"
    } > "$MKTEMP_SHIM_DIR/mktemp"
    chmod +x "$MKTEMP_SHIM_DIR/mktemp"
    set +e
    wo_out="$(WRITEONLY_BODY="$WRITEONLY_BODY" PATH="$MKTEMP_SHIM_DIR:$PATH" \
        bash "$SCRIPT" prompt "$DOC" CASE-A1 "$FIXTURES_DIR/valid" 2>&1)"
    wo_rc=$?
    set -e
    wo_ok=1
    wo_detail=""
    [ "$wo_rc" -eq 1 ] || { wo_ok=0; wo_detail="exit code 期待 1 / 実際 $wo_rc"; }
    case "$wo_out" in
        *"題材文を一時ファイルから読めなかった"*) ;;
        *) wo_ok=0; wo_detail="${wo_detail}${wo_detail:+ / }原因を名指ししていない" ;;
    esac
    for needle in "プロンプトの組み立てに失敗した" "prompt-template.md"; do
        if ! assert_not_contains "$wo_out" "$needle"; then
            wo_ok=0
            wo_detail="${wo_detail}${wo_detail:+ / }診断が重なって原因を取り違えている: $needle"
        fi
    done
    record "50. prompt（題材文の一時ファイルを読めない）→ 原因を1度だけ名指しし、雛形の異常終了へ化けない" "$wo_ok" "$wo_detail"
fi
# 書き込み専用ファイルは被テスト側の EXIT trap が消していることがあるので、
# 掃除は親ディレクトリごとに行う（ファイル単体の chmod は空振りして落ちる）。
rm -rf "$MKTEMP_SHIM_DIR"

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
#
# 拡張子で絞らないのは、`hooks/adr-commit-gate`（拡張子なし）と `hooks/run-hook.cmd` が
# 絞り込みから漏れるためである。`-I` でバイナリだけ除く。
# 副作用として走査が配布物内の全テキストファイルへ広がるため、将来 `#123456` 形式の
# 色コード等を含むファイルが入ると偽陽性になりうる。現時点で該当は無い。
#
# アサーション42 の走査（ディレクトリ構成・リポジトリ名・対象文書名）は本走査と違って
# 配布物全体へ広げない。他の同梱スクリプトは既定値や使い方の説明として `docs/adr` 等を
# 正当に含んでおり（`lint-adr.sh:149` の `ADR_DIR="${1:-docs/adr}"` ほか計5ファイル）、
# 広げると偽陽性になる。42 が被テストの検査器1本に閉じているのは、この検査器だけが
# 「既定値を持たず全パスを引数で受ける」建て付けを取っているからである。
issue_ref_hits="$(grep -rInE '(^|[^A-Za-z0-9_])#[0-9]{2,}' "$REPO_ROOT/plugins/adr" || true)"
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
