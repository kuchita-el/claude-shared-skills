#!/usr/bin/env bats
# 固定題材集合の実行支援スクリプト（plugins/adr/scripts/adr-scoping-cases.sh）のテスト（特殊系）。
#
# 環境操作を伴うケースを持つ。パス・環境・題材の大きさといった利用者側の入力によって
# 無言で誤った出力を出す／診断ゼロで落ちる欠陥に対する回帰保護が中心である。
# 基本系（サブコマンドと fixture の組み合わせ）は adr-scoping-cases-basic.bats が持つ。
#
# 一時ディレクトリとパーミッション操作は BATS_TEST_TMPDIR を使い、パーミッションを変えた
# ものは判定後に必ず戻す（戻さないと bats の tmpdir 掃除自体が失敗する）。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。

load 'helpers/common'
load 'helpers/adr-scoping-cases'

SUT="$PLUGIN_ROOT/scripts/adr-scoping-cases.sh"
CASES_DIR="$FIXTURES_DIR/adr-scoping-cases"
JUDGMENTS_DIR="$CASES_DIR/judgments"
DOC="$REPO_ROOT/CLAUDE.md"

CORPORA=()
PRECONDITION_PATHS=("$CASES_DIR/valid" "$CASES_DIR/scan-order" "$JUDGMENTS_DIR" "$DOC")

# 診断の走査順の検査で使う期待並び。fixture の題材IDは、素朴な走査だと gawk・mawk の
# いずれでも出現順と異なる並びになる組み合わせを選んである。
SCAN_ORDER_IDS="CASE-A1 CASE-ZZ CASE-M3 CASE-B2 CASE-Q9 CASE-D4"

# 40a のラベルは `$` と `'` が同居するため、どちらのクォート形式でも逐語では書けない。
# 移行等価性の突き合わせ（grep -F）が本文の文字列一致で行われるため、引用符を解釈しない
# ヒアドキュメントで逐語のまま持つ。
LABEL_40A=$(
    cat <<'EOF'
40a. prompt/validate/report（$TMPDIR に it's を含む）→ 通常環境と report 経路（期待帰結読込を含む）が一致する
EOF
)

setup_file() {
    common_setup_file
}

# パーミッションを変えたディレクトリ・ファイルが残ったままだと、bats の tmpdir 掃除自体が
# 失敗する。各ケース内でも戻しているが、途中で abort した場合に備えて teardown でも
# 一括で戻す（teardown は errexit で abort した @test の後でも走る）。
teardown() {
    [ -n "${BATS_TEST_TMPDIR:-}" ] || return 0
    chmod -R u+rwX "$BATS_TEST_TMPDIR" 2>/dev/null || true
    return 0
}

# ---------------------------------------------------------------- 判定の部品

sc() {
    run bash "$SUT" "$@" </dev/null
}

sc_stdout() {
    run --separate-stderr bash "$SUT" "$@" </dev/null
}

collect_run() {
    local want_rc="$1" label="$2"
    shift 2
    local ok=1 detail="" p
    if [ "$status" -ne "$want_rc" ]; then
        ok=0
        detail="exit code 期待 $want_rc / 実際 $status"
    fi
    for p in "$@"; do
        case "$output" in
            *"$p"*) ;;
            *) ok=0 detail="${detail}${detail:+ / }出力に含まれない: $p" ;;
        esac
    done
    if [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail"$'\n       出力:\n'"$output"
    fi
    return 0
}

copy_valid_case_dir() {
    local dest="$1"
    mkdir -p "$dest"
    cp "$CASES_DIR/valid/cases.md" "$CASES_DIR/valid/expectations.tsv" \
        "$CASES_DIR/valid/prompt-template.md" "$dest/"
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

# 診断の並びが期待どおりであることを収集する。
# $1 対象文字列 / $2 診断行を絞る正規表現 / $3 期待する題材IDの並び / $4 ラベル
collect_case_id_order() {
    local text="$1" pat="$2" want="$3" label="$4" got
    got="$(first_case_ids "$pat" "$text")"
    if [ "$got" = "$want" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "並び 期待 [$want] / 実際 [$got]"
    fi
    return 0
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
    } >"$shim_dir/awk"
    chmod +x "$shim_dir/awk"
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

# ---------------------------------------------------------------- 利用者入力の取り扱い

# 対象文書パス・$TMPDIR・題材集合ディレクトリのいずれに `&` `\` `'` が現れても、
# 差し込み記号の再挿入・trap の破壊・期待帰結の読み落としを起こしてはならない。
# いずれも exit 0 のまま誤った出力を出す（結論が無言で反転する）同型の欠陥である。
@test "面①: 利用者入力の取り扱い" {
    collect_init

    # awk の gsub は置換文字列中の `&` をマッチ文字列へ展開し、`-v` は代入値のエスケープ列を
    # 解釈する。いずれも素朴に書くと exit 0 のまま誤った内容のプロンプトが出来上がる。
    local amp_dir="$BATS_TEST_TMPDIR/amp/di&r\\x"
    local amp_label='39. prompt（対象文書パスに & と \ を含む）→ 差し込み記号を再挿入せず、パスをそのまま載せる'
    local amp_ok=1 amp_detail="" amp_body
    mkdir -p "$amp_dir"
    cp "$DOC" "$amp_dir/doc.md"
    sc_stdout prompt "$amp_dir/doc.md" CASE-A1 "$CASES_DIR/valid"
    if [ "$status" -ne 0 ] || [ ! -f "$output" ]; then
        amp_ok=0
        amp_detail="prompt が組み立てに失敗した (rc=$status)"
    else
        amp_body="$(cat "$output")"
        rm -f "$output"
        case "$amp_body" in
            *"{{対象文書パス}}"*) amp_ok=0 amp_detail="差し込み記号が出力へ再挿入されている（gsub の & 展開）" ;;
        esac
        case "$amp_body" in
            *"$amp_dir/doc.md"*) ;;
            *) amp_ok=0 amp_detail="${amp_detail}${amp_detail:+ / }対象文書パスがそのまま差し込まれていない" ;;
        esac
    fi
    [ "$amp_ok" -eq 1 ] && collect_ok "$amp_label" || collect_fail "$amp_label" "$amp_detail"

    # $TMPDIR に単一引用符や `\` が含まれても、後始末の trap が壊れず、
    # 題材文が空のままのプロンプトが出来上がってもならない。
    # 前者は EXIT trap のクォート破壊で exit 2、後者は awk -v のエスケープ解釈で
    # 一時ファイルのパスが壊れ、題材文の差し込みが1行も回らないことによる。
    # 同じ異常な $TMPDIR を prompt だけでなく validate / report へも流す。同型の欠陥は
    # 一時ファイルと awk を使うサブコマンドすべてに現れうるため、片方だけ試すと取りこぼす。
    check_weird_tmpdir "it's" "$LABEL_40A"
    check_weird_tmpdir 'back\slash' \
        '40b. prompt/validate/report（$TMPDIR に back\slash を含む）→ 通常環境と report 経路（期待帰結読込を含む）が一致する'

    # 題材集合ディレクトリのパスそのものに `&` と `\` が含まれる場合。
    # awk -v のエスケープ解釈で期待帰結ファイルを読めないと、report は無言で
    # 「差は無い」へ倒れる（診断ゼロで結論だけが反転する経路）。
    local weird_dir="$BATS_TEST_TMPDIR/weird/di&r\\x"
    copy_valid_case_dir "$weird_dir"
    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline_report_status="$status" baseline_report_output="$output"
    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$weird_dir"
    local report_ok=1 report_detail=""
    [ "$baseline_report_status" -eq 0 ] || report_ok=0 report_detail="通常環境 report: rc=$baseline_report_status"
    [ "$status" -eq 0 ] || report_ok=0 report_detail="${report_detail}${report_detail:+ / }特殊文字パス report: rc=$status"
    [ "$output" = "$baseline_report_output" ] || report_ok=0 report_detail="${report_detail}${report_detail:+ / }通常環境と特殊文字パスの report 出力が一致しない"
    [ "$report_ok" -eq 1 ] \
        && collect_ok '40c. report（題材集合ディレクトリのパスに & と \ を含む）→ 通常環境と report 経路（期待帰結読込を含む）が一致する' \
        || collect_fail '40c. report（題材集合ディレクトリのパスに & と \ を含む）→ 通常環境と report 経路（期待帰結読込を含む）が一致する' "$report_detail"
    sc validate "$weird_dir"
    collect_run 0 '40d. validate（題材集合ディレクトリのパスに & と \ を含む）→ exit 0' \
        "題材集合の検査に通った"

    collect_finish
}

# 面①の下請け。異常な $TMPDIR を prompt / validate / report の3経路へ通す。
check_weird_tmpdir() {
    local weird="$1" label="$2"
    # 親を $weird ごとに分けることで、2回の呼び出しが同じパスを共有しないようにする。
    local tmp="$BATS_TEST_TMPDIR/weird-tmp/$weird"
    local ok=1 detail="" path
    mkdir -p "$tmp"

    run --separate-stderr env TMPDIR="$tmp" bash "$SUT" prompt "$DOC" CASE-A1 "$CASES_DIR/valid" </dev/null
    path="$output"
    if [ "$status" -ne 0 ] || [ -n "$stderr" ]; then
        ok=0
        detail="prompt: rc=$status / stderr=$stderr"
    elif [ ! -f "$path" ]; then
        ok=0
        detail="prompt: 出力ファイルが無い: $path"
    else
        case "$(cat "$path")" in
            *"コミットを止める"*) ;;
            *) ok=0 detail="prompt: 題材文が差し込まれていない（空のプロンプト）" ;;
        esac
        rm -f "$path"
    fi

    # validate と report も同じ $TMPDIR で通す。report は通常環境の出力を baseline として
    # 比較し、期待帰結の読込を含む経路の無言の結論反転を捕まえる。
    run env TMPDIR="$tmp" bash "$SUT" validate "$CASES_DIR/valid" </dev/null
    [ "$status" -eq 0 ] || ok=0 detail="${detail}${detail:+ / }validate: rc=$status / $output"

    run bash "$SUT" report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid" </dev/null
    local baseline_report_status="$status" baseline_report_output="$output"
    run env TMPDIR="$tmp" bash "$SUT" report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid" </dev/null
    [ "$baseline_report_status" -eq 0 ] || ok=0 detail="${detail}${detail:+ / }通常環境 report: rc=$baseline_report_status"
    [ "$status" -eq 0 ] || ok=0 detail="${detail}${detail:+ / }特殊文字 TMPDIR report: rc=$status / $output"
    [ "$output" = "$baseline_report_output" ] || ok=0 detail="${detail}${detail:+ / }通常環境と特殊文字 TMPDIR の report 出力が一致しない"

    [ "$ok" -eq 1 ] && collect_ok "$label" || collect_fail "$label" "$detail"
    return 0
}

# ---------------------------------------------------------------- 診断の走査順

# 連想配列を素朴に `for (k in arr)` で走査すると、診断の並びが awk の実装依存になる。
# 出力は集計レポートへ貼り込むため、記載・記録の出現順に固定されていなければならない。
# 部分一致のアサーションでは「含まれてはいるが並びだけが違う」退行を通してしまうため、
# 以下4件は並びそのものを突き合わせる。
@test "面②: 診断の走査順" {
    collect_init

    sc report "$JUDGMENTS_DIR/unknown-id-multi-judgments.tsv" "$CASES_DIR/valid"
    collect_case_id_order "$output" "題材集合に無い題材IDの行" "CASE-ZZ CASE-M3 CASE-B2 CASE-Q9 CASE-D4" \
        "43a. report（未知の題材IDが複数）→ 診断が記録の出現順で並ぶ"

    sc report "$JUDGMENTS_DIR/scan-order-dupe-judgments.tsv" "$CASES_DIR/scan-order"
    collect_case_id_order "$output" "重複した行" "$SCAN_ORDER_IDS" \
        "43b. report（重複した行が複数）→ 診断が記録の出現順で並ぶ"

    sc report "$JUDGMENTS_DIR/scan-order-badcommit-judgments.tsv" "$CASES_DIR/scan-order"
    collect_case_id_order "$output" "短縮ハッシュでない" "$SCAN_ORDER_IDS" \
        "43c. report（commit 列の未確定が複数）→ 診断が記録の出現順で並ぶ"

    sc validate "$CASES_DIR/scan-order"
    collect_case_id_order "$output" "対の相手ID が題材集合に無い" "$SCAN_ORDER_IDS" \
        "43d. validate（対の相手IDが題材集合に無い題材が複数）→ 診断が記載の出現順で並ぶ"

    collect_finish
}

# ---------------------------------------------------------------- 集計の異常終了と打ち切りの区別

# gawk・mawk とも fatal error では exit 2 を返す。打ち切りの番兵に 2 を使うと、
# 呼び出し側が awk の異常終了を「期待帰結を読めなかった」と読み違え、無関係な
# expectations.tsv のパスを名指しする。以下3件で、各経路が別の原因として出ることを見る。
@test "面③: awk の異常終了と打ち切りの区別" {
    collect_init

    local shim_dir="$BATS_TEST_TMPDIR/awk-shim"
    make_awk_shim "$shim_dir"

    # 集計そのものが異常終了した場合（awk の fatal = exit 2）。打ち切りの番兵と衝突していると、
    # 期待帰結を読めていたにもかかわらず「期待帰結を読めなかった」と表示される。
    local shim_label="48. report（集計そのものが異常終了）→ 判定記録TSV を名指しし、期待帰結の打ち切りと取り違えない"
    local shim_ok=1 shim_detail="" needle
    run env AWK_SHIM_COUNT="$shim_dir/count" AWK_SHIM_FAIL_AT=1 PATH="$shim_dir:$PATH" \
        bash "$SUT" report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid" </dev/null
    [ "$status" -eq 1 ] || shim_ok=0 shim_detail="exit code 期待 1 / 実際 $status"
    case "$output" in
        *"判定記録の集計に失敗した"*) ;;
        *) shim_ok=0 shim_detail="${shim_detail}${shim_detail:+ / }集計の失敗として告げていない" ;;
    esac
    for needle in "期待帰結を読めなかった" "expectations.tsv"; do
        case "$output" in
            *"$needle"*) shim_ok=0 shim_detail="${shim_detail}${shim_detail:+ / }打ち切り経路と取り違えている: $needle" ;;
        esac
    done
    [ "$shim_ok" -eq 1 ] && collect_ok "$shim_label" || collect_fail "$shim_label" "$shim_detail"

    # prompt の組み立ての awk が異常終了した場合。診断ゼロで抜けると、中身の欠けた
    # 一時ファイルだけが $TMPDIR に残る。原因を名指しし、かつ残さないことを見る。
    local sp_tmpdir="$BATS_TEST_TMPDIR/shim-prompt-tmp"
    local sp_label="49. prompt（組み立ての処理が異常終了）→ 原因を名指しして落ち、一時ファイルを残さない"
    local sp_ok=1 sp_detail="" sp_left
    mkdir -p "$sp_tmpdir"
    : >"$shim_dir/count"
    run env AWK_SHIM_COUNT="$shim_dir/count" AWK_SHIM_FAIL_AT=2 TMPDIR="$sp_tmpdir" \
        PATH="$shim_dir:$PATH" bash "$SUT" prompt "$DOC" CASE-A1 "$CASES_DIR/valid" </dev/null
    sp_left="$(find "$sp_tmpdir" -type f | wc -l | tr -d ' ')"
    [ "$status" -eq 1 ] || sp_ok=0 sp_detail="exit code 期待 1 / 実際 $status"
    case "$output" in
        *"プロンプトの組み立てに失敗した"*) ;;
        *) sp_ok=0 sp_detail="${sp_detail}${sp_detail:+ / }スクリプト自身の診断が出ていない" ;;
    esac
    [ "$sp_left" -eq 0 ] || sp_ok=0 sp_detail="${sp_detail}${sp_detail:+ / }\$TMPDIR に $sp_left 件残った"
    [ "$sp_ok" -eq 1 ] && collect_ok "$sp_label" || collect_fail "$sp_label" "$sp_detail"

    # 組み立ての awk は、題材文の一時ファイルを1行も読めなかったときに自前で診断を出して
    # 番兵 3 で落ちる。呼び出し側の `||` ハンドラがこれを awk の異常終了と区別できないと、
    # 原因を名指しした1行目の後ろへ「異常終了した」と述べる2行目が積まれ、無関係な
    # prompt-template.md が名指しされる（cmd_report で番兵 3 を入れて解いたのと同型）。
    #
    # 一時ファイルを書き込み専用（200）で先に作らせることで、書き込みは通り読み込みだけが
    # 落ちる状況を決定的に作る。mktemp の代役は序数ではなく雛形の名前で分岐させる。
    local mk_dir="$BATS_TEST_TMPDIR/mktemp-shim"
    local writeonly_body="$mk_dir/body-writeonly"
    local wo_label="50. prompt（題材文の一時ファイルを読めない）→ 原因を1度だけ名指しし、雛形の異常終了へ化けない"
    mkdir -p "$mk_dir"
    : >"$writeonly_body"
    chmod 200 "$writeonly_body"
    if [ -r "$writeonly_body" ]; then
        # root 実行等で読めてしまう環境では成立しない検査なので、その旨を告知して飛ばす
        collect_skipped "$wo_label" "chmod 200 でも読める環境のため未実行"
    else
        {
            printf '#!/usr/bin/env bash\n'
            printf 'for a in "$@"; do case "$a" in *adr-scoping-case-body*) printf %%s\\\\n "$WRITEONLY_BODY"; exit 0 ;; esac; done\n'
            printf 'exec %s "$@"\n' "$(command -v mktemp)"
        } >"$mk_dir/mktemp"
        chmod +x "$mk_dir/mktemp"
        local wo_ok=1 wo_detail=""
        run env WRITEONLY_BODY="$writeonly_body" PATH="$mk_dir:$PATH" \
            bash "$SUT" prompt "$DOC" CASE-A1 "$CASES_DIR/valid" </dev/null
        [ "$status" -eq 1 ] || wo_ok=0 wo_detail="exit code 期待 1 / 実際 $status"
        case "$output" in
            *"題材文を一時ファイルから読めなかった"*) ;;
            *) wo_ok=0 wo_detail="${wo_detail}${wo_detail:+ / }原因を名指ししていない" ;;
        esac
        for needle in "プロンプトの組み立てに失敗した" "prompt-template.md"; do
            case "$output" in
                *"$needle"*) wo_ok=0 wo_detail="${wo_detail}${wo_detail:+ / }診断が重なって原因を取り違えている: $needle" ;;
            esac
        done
        [ "$wo_ok" -eq 1 ] && collect_ok "$wo_label" || collect_fail "$wo_label" "$wo_detail"
    fi
    # 書き込み専用ファイルは被テスト側の EXIT trap が消していることがあるので、
    # 掃除の前にパーミッションを戻す（消えていれば chmod は空振りするため無視する）。
    chmod 644 "$writeonly_body" 2>/dev/null || true

    collect_finish
}

# ---------------------------------------------------------------- 期待帰結の不在

@test "面④: 期待帰結の不在" {
    collect_init

    # 期待帰結を1件も読めないまま集計を続けると「差は無い」と出て結論が無言で反転する。
    # 診断が出ることだけを見ても足りない。awk の exit は BEGIN で呼んでも END を飛ばさないため、
    # 診断の直後に集計本文が最後まで印字される状態を通してしまう。本文が出ないことまで見る。
    local noexp_dir="$BATS_TEST_TMPDIR/noexp"
    local noexp_label="40e. report（期待帰結を1件も読めない）→ 診断とラベルの両方で理由を告げ、集計本文を1行も印字しない"
    local noexp_ok=1 noexp_detail="" needle
    mkdir -p "$noexp_dir"
    cp "$CASES_DIR/valid/cases.md" "$CASES_DIR/valid/prompt-template.md" "$noexp_dir/"
    printf '# 注記行だけで期待帰結の行を持たない\n' >"$noexp_dir/expectations.tsv"
    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$noexp_dir"
    [ "$status" -eq 1 ] || noexp_ok=0 noexp_detail="exit code 期待 1 / 実際 $status"
    case "$output" in
        *"期待帰結を1件も読めなかった"*) ;;
        *) noexp_ok=0 noexp_detail="${noexp_detail}${noexp_detail:+ / }診断が出ていない" ;;
    esac
    for needle in "差は無い" "== カバレッジ ==" "== 期待帰結との差 =="; do
        case "$output" in
            *"$needle"*) noexp_ok=0 noexp_detail="${noexp_detail}${noexp_detail:+ / }集計本文が印字されている: $needle" ;;
        esac
    done
    # awk の終了状態を一律で畳むと、末尾のラベルが原因を取り違える（期待帰結を読めなかった
    # のに「判定記録の集計に失敗した」＝既定の枝が出る）。打ち切りの理由がラベルにも表れる
    # ことと、既定の枝へ落ちていないことの両方を見る。needle は現に printf される文字列で
    # なければ空振りするので、`case "$rc"` のラベルを変えたときはここも合わせること。
    case "$output" in
        *"期待帰結を読めなかったため集計を打ち切った"*) ;;
        *) noexp_ok=0 noexp_detail="${noexp_detail}${noexp_detail:+ / }打ち切りの理由がラベルに出ていない" ;;
    esac
    case "$output" in
        *"判定記録の集計に失敗した"*) noexp_ok=0 noexp_detail="${noexp_detail}${noexp_detail:+ / }ラベルが既定の枝（判定記録の集計に失敗した）へ落ちている" ;;
    esac
    [ "$noexp_ok" -eq 1 ] && collect_ok "$noexp_label" || collect_fail "$noexp_label" "$noexp_detail"

    # 題材が0件の題材集合では、カバレッジ側が別理由で落とすこともない。
    # 期待帰結の未読を BEGIN の exit だけで扱っていると、この組み合わせが rc=0 で素通りする。
    local noexp0_dir="$BATS_TEST_TMPDIR/noexp0"
    local noexp0_label="40f. report（期待帰結も題材も0件）→ 素通りせず、「差は無い」も印字しない"
    local noexp0_ok=1 noexp0_detail=""
    mkdir -p "$noexp0_dir"
    printf '# 題材を1件も持たない cases.md\n' >"$noexp0_dir/cases.md"
    cp "$CASES_DIR/valid/prompt-template.md" "$noexp0_dir/"
    printf '# 注記行だけで期待帰結の行を持たない\n' >"$noexp0_dir/expectations.tsv"
    sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$noexp0_dir"
    [ "$status" -ne 0 ] || noexp0_ok=0 noexp0_detail="exit code 0 で素通りした"
    case "$output" in
        *"差は無い"*) noexp0_ok=0 noexp0_detail="${noexp0_detail}${noexp0_detail:+ / }「差は無い」が印字されている" ;;
    esac
    [ "$noexp0_ok" -eq 1 ] && collect_ok "$noexp0_label" || collect_fail "$noexp0_label" "$noexp0_detail"

    collect_finish
}

# ---------------------------------------------------------------- report の層分離

@test "面⑪変異ゲート: 表示層の変更は通し、統計値の変更は止める" {
    collect_init

    local mutant_dir="$BATS_TEST_TMPDIR/report-mutants"
    mkdir -p "$mutant_dir"

    mutation_lines() {
        local original="$1" mutant="$2" diff_file="$BATS_TEST_TMPDIR/mutation.diff"
        diff -u "$original" "$mutant" >"$diff_file" || true
        awk 'NR > 2 && /^-/ { n++ } END { print n + 0 }' "$diff_file"
    }

    local display_mutant="$mutant_dir/display.sh"
    sed '/ncases - miss/s/say(sprintf("  題材/say(sprintf("  [表示変更] 題材/' "$SUT" >"$display_mutant"
    chmod +x "$display_mutant"
    local display_lines
    display_lines="$(mutation_lines "$SUT" "$display_mutant")"
    [ "$display_lines" -eq 1 ] && collect_ok "表示文言の変異が1箇所だけ適用される" || \
        collect_fail "表示文言の変異が1箇所だけ適用される" "差分行数: $display_lines"
    stats_run "$SUT" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline_stats="$output"
    stats_run "$display_mutant" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    if [ "$status" -eq 0 ] && [ "$output" = "$baseline_stats" ]; then
        case "$stderr" in
            *"[表示変更]"*) collect_ok "表示文言だけの変異は統計値の突き合わせを通る" ;;
            *) collect_fail "表示文言だけの変異は統計値の突き合わせを通る" "本文側へ変異が現れていない" ;;
        esac
    else
        collect_fail "表示文言だけの変異は統計値の突き合わせを通る" "status=$status stdout=$output stderr=$stderr"
    fi

    local body_mutant="$mutant_dir/body.sh"
    sed '/合計: 一致/s/tagree/agree/' "$SUT" >"$body_mutant"
    chmod +x "$body_mutant"
    local body_lines
    body_lines="$(mutation_lines "$SUT" "$body_mutant")"
    [ "$body_lines" -eq 1 ] && collect_ok "本文数値の変異が1箇所だけ適用される" || \
        collect_fail "本文数値の変異が1箇所だけ適用される" "差分行数: $body_lines"
    stats_run "$SUT" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline_body_stats baseline_body_ratios
    baseline_body_stats="$output"
    baseline_body_ratios="$(stats_body_ratios "$stderr")"
    stats_run "$body_mutant" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    if [ "$status" -eq 0 ] && [ "$output" = "$baseline_body_stats" ] && \
        [ "$(stats_body_ratios "$stderr")" != "$baseline_body_ratios" ]; then
        collect_ok "本文数値だけの変異は本文と統計値の突き合わせで止まる"
    else
        collect_fail "本文数値だけの変異は本文と統計値の突き合わせで止まる" "本文の数値変異を検出できない"
    fi

    local coverage_mutant="$mutant_dir/coverage.sh"
    sed 's/say(sprintf("  題材 %d 件中 %d 件を記録が覆う", ncases,/say(sprintf("  題材 %d 件中 %d 件を記録が覆う", ncases + 3,/' "$SUT" >"$coverage_mutant"
    chmod +x "$coverage_mutant"
    local coverage_lines
    coverage_lines="$(mutation_lines "$SUT" "$coverage_mutant")"
    [ "$coverage_lines" -eq 1 ] && collect_ok "本文カバレッジ件数の変異が1箇所だけ適用される" || \
        collect_fail "本文カバレッジ件数の変異が1箇所だけ適用される" "差分行数: $coverage_lines"
    stats_run "$SUT" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline_coverage_stats baseline_coverage_body
    baseline_coverage_stats="$output"
    baseline_coverage_body="$(stats_body_coverage "$stderr")"
    stats_run "$coverage_mutant" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    if [ "$status" -eq 0 ] && [ "$output" = "$baseline_coverage_stats" ] && \
        [ "$(stats_body_coverage "$stderr")" != "$baseline_coverage_body" ]; then
        collect_ok "本文カバレッジ件数だけの変異は本文と統計値の突き合わせで止まる"
    else
        collect_fail "本文カバレッジ件数だけの変異は本文と統計値の突き合わせで止まる" "本文のカバレッジ件数変異を検出できない"
    fi

    local cells_mutant="$mutant_dir/cells.sh"
    sed 's/agree++; iagree\[i\]++/agree += 2; iagree[i]++/' "$SUT" >"$cells_mutant"
    chmod +x "$cells_mutant"
    local cells_lines
    cells_lines="$(mutation_lines "$SUT" "$cells_mutant")"
    [ "$cells_lines" -eq 1 ] && collect_ok "一致セル数の変異が1箇所だけ適用される" || \
        collect_fail "一致セル数の変異が1箇所だけ適用される" "差分行数: $cells_lines"
    stats_run "$SUT" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local baseline_cells baseline_cells_total
    baseline_cells="$(stats_value agreement.cells.matched)"
    baseline_cells_total="$(stats_value agreement.cells.total)"
    stats_run "$cells_mutant" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
    local mutated_cells
    mutated_cells="$(stats_value agreement.cells.matched)"
    if [ "$status" -eq 0 ] && [ -n "$baseline_cells" ] && [ "$mutated_cells" != "$baseline_cells" ]; then
        case " $(stats_body_ratios "$stderr") " in
            *" $mutated_cells/$baseline_cells_total "*) collect_ok "一致セル数の変異は統計値と本文の双方に現れる" ;;
            *) collect_fail "一致セル数の変異は統計値と本文の双方に現れる" "本文側に同じずれが無い: $stderr" ;;
        esac
    else
        collect_fail "一致セル数の変異は統計値と本文の双方に現れる" "統計値の変異が不一致にならない: $output"
    fi

    local diff_mutant="$mutant_dir/diff.sh"
    sed '/exp_item.*ndiff++/s/ndiff++/ndiff += 0/' "$SUT" >"$diff_mutant"
    chmod +x "$diff_mutant"
    local diff_lines
    diff_lines="$(mutation_lines "$SUT" "$diff_mutant")"
    [ "$diff_lines" -eq 1 ] && collect_ok "差の件数の変異が1箇所だけ適用される" || \
        collect_fail "差の件数の変異が1箇所だけ適用される" "差分行数: $diff_lines"
    stats_run "$SUT" "$JUDGMENTS_DIR/expectation-diff-multi-judgments.tsv" "$CASES_DIR/valid"
    local baseline_diff
    baseline_diff="$(stats_value diff.count)"
    stats_run "$diff_mutant" "$JUDGMENTS_DIR/expectation-diff-multi-judgments.tsv" "$CASES_DIR/valid"
    local mutated_diff
    mutated_diff="$(stats_value diff.count)"
    if [ "$status" -eq 0 ] && [ -n "$baseline_diff" ] && [ "$mutated_diff" != "$baseline_diff" ]; then
        if [ "$(stats_body_last_count "$stderr")" = "$mutated_diff" ]; then
            collect_ok "差の件数の変異は統計値と本文の双方に現れる"
        else
            collect_fail "差の件数の変異は統計値と本文の双方に現れる" "本文側に同じずれが無い: $stderr"
        fi
    else
        collect_fail "差の件数の変異は統計値と本文の双方に現れる" "統計値の変異が不一致にならない: $output"
    fi

    local no_change_mutant="$mutant_dir/no-change.sh"
    sed 's/文字列として存在しない置換対象/変異/' "$SUT" >"$no_change_mutant"
    chmod +x "$no_change_mutant"
    local no_change_lines
    no_change_lines="$(mutation_lines "$SUT" "$no_change_mutant")"
    [ "$no_change_lines" -eq 0 ] && collect_ok "無置換の変異は事前検査で拒否できる" || \
        collect_fail "無置換の変異は事前検査で拒否できる" "差分行数: $no_change_lines"

    local broad_mutant="$mutant_dir/broad-change.sh"
    sed 's/ndiff++/ndiff += 0/g' "$SUT" >"$broad_mutant"
    chmod +x "$broad_mutant"
    local broad_lines
    broad_lines="$(mutation_lines "$SUT" "$broad_mutant")"
    [ "$broad_lines" -gt 1 ] && collect_ok "複数箇所へ当たる変異は事前検査で拒否できる" || \
        collect_fail "複数箇所へ当たる変異は事前検査で拒否できる" "差分行数: $broad_lines"

    collect_finish
}

@test "面⑪mawk: report --stats が想定実装でも動く" {
    collect_init
    if ! command -v mawk >/dev/null 2>&1; then
        collect_skipped "mawk で report --stats を実行する" "mawk が無い環境のため未実行"
    else
        local awk_shim="$BATS_TEST_TMPDIR/mawk-bin"
        mkdir -p "$awk_shim"
        printf '#!/usr/bin/env bash\nexec mawk "$@"\n' >"$awk_shim/awk"
        chmod +x "$awk_shim/awk"
        PATH="$awk_shim:$PATH" stats_run "$SUT" "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"
        collect_stats 0 "mawk で report --stats が統計値を出す" \
            coverage.cases=2 coverage.covered=2 agreement.cells.matched=7 diff.count=1
    fi
    collect_finish
}

# ---------------------------------------------------------------- 配布物の非依存性

# 配布物内のスクリプトが配布元リポジトリ固有の名前を知らないことを機械検査する。
# 検査器は題材集合ディレクトリと対象文書パスを引数でのみ受け取る建て付けであり、
# 固有名がコードパスへ現れた時点でその建て付けが崩れる。
# 走査は既知の固有名のリストであり、リストに無い新種は検出できない。
@test "面⑤: 配布物の非依存性" {
    collect_init

    local repo_specific_hits issue_ref_hits
    local label42="42. 配布物内のスクリプトが配布元リポジトリ固有の名前（ディレクトリ構成・リポジトリ名・対象文書名）を含まない"
    repo_specific_hits="$(grep -nE 'docs/|plugins/|scripts/|\.claude/|adr-scoping\.md|claude-shared-skills|manage-adr' "$SUT" || true)"
    if [ -z "$repo_specific_hits" ]; then
        collect_ok "$label42"
    else
        collect_fail "$label42" "検出:"$'\n'"$repo_specific_hits"
    fi

    # 同じ原則は配布物のドキュメントにも及ぶ。配布先の利用者から見て Issue 番号は解決できない
    # 参照であり、追跡の記録は配布物外（ADR の関連Issue 行・配布元の開発ドキュメント・
    # 本テスト）へ置く。アサーション42 の走査対象はスクリプト本体のみで、実際にこの型の
    # 混入を README で1件取りこぼしたため、走査を配布物全体へ広げる。
    #
    # 拡張子で絞らないのは、`hooks/adr-commit-gate`（拡張子なし）と `hooks/run-hook.cmd` が
    # 絞り込みから漏れるためである。`-I` でバイナリだけ除く。
    # 副作用として走査が配布物内の全テキストファイルへ広がるため、将来 `#123456` 形式の
    # 色コード等を含むファイルが入ると偽陽性になりうる。現時点で該当は無い。
    #
    # アサーション42 の走査（ディレクトリ構成・リポジトリ名・対象文書名）は本走査と違って
    # 配布物全体へ広げない。他の同梱スクリプトは既定値や使い方の説明として `docs/adr` 等を
    # 正当に含んでおり（`lint-adr.sh` の `ADR_DIR="${1:-docs/adr}"` ほか計5ファイル）、
    # 広げると偽陽性になる。42 が被テストの検査器1本に閉じているのは、この検査器だけが
    # 「既定値を持たず全パスを引数で受ける」建て付けを取っているからである。
    local label44="44. 配布物（plugins/adr 配下）が配布元リポジトリの Issue 番号を含まない"
    issue_ref_hits="$(grep -rInE '(^|[^A-Za-z0-9_])#[0-9]{2,}' "$PLUGIN_ROOT" || true)"
    if [ -z "$issue_ref_hits" ]; then
        collect_ok "$label44"
    else
        collect_fail "$label44" "検出:"$'\n'"$issue_ref_hits"
    fi

    collect_finish
}

# ---------------------------------------------------------------- 大入力

# メタ行が多い題材でも、パイプの早期終了による SIGPIPE で診断ゼロのまま落ちてはならない。
# 読み手を先に閉じても書き手を先に閉じても pipefail + set -e で rc=141 になるため、
# パイプ長より十分大きいメタ行を与えて両側が最後まで生きることを確かめる。
@test "面⑥: 大入力" {
    collect_init

    local big_dir="$BATS_TEST_TMPDIR/big"
    mkdir -p "$big_dir"
    cp "$CASES_DIR/valid/expectations.tsv" "$CASES_DIR/valid/prompt-template.md" "$big_dir/"
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
    ' "$CASES_DIR/valid/cases.md" >"$big_dir/cases.md"

    sc validate "$big_dir"
    collect_run 0 "41. validate（メタ行がパイプ長を超える題材）→ 診断ゼロの異常終了をせず検査を完了する" \
        "題材集合の検査に通った"

    collect_finish
}

# ---------------------------------------------------------------- 一時ファイルの後始末と読み取り不能

@test "面⑦: 一時ファイルの後始末と入出力の読み取り不能" {
    collect_init

    # prompt が成功した場合、$TMPDIR に残るのは呼び出し側へ返したプロンプト1件だけであること。
    # 作業用の一時ファイルの後始末と、出力用ファイルを後始末の対象から外す位置の両方に効く
    # （外し忘れると EXIT trap が返したファイルごと消し、外すのが早すぎると作業用が残る）。
    # なお awk が落ちる経路での出力用ファイルの後始末は、決定的に起こせる引き金が無いため
    # ここでは押さえられていない。
    local leak_tmpdir="$BATS_TEST_TMPDIR/leak"
    local leak_label='46. prompt 成功時、$TMPDIR に残るのは返したプロンプト1件だけ（作業用の一時ファイルを残さず、返すファイルも消さない）'
    local leak_ok=1 leak_detail="" leak_path leak_count
    mkdir -p "$leak_tmpdir"
    run --separate-stderr env TMPDIR="$leak_tmpdir" bash "$SUT" prompt "$DOC" CASE-A1 "$CASES_DIR/valid" </dev/null
    leak_path="$output"
    leak_count="$(find "$leak_tmpdir" -type f | wc -l | tr -d ' ')"
    [ "$status" -eq 0 ] || leak_ok=0 leak_detail="rc=$status"
    [ -f "$leak_path" ] || leak_ok=0 leak_detail="${leak_detail}${leak_detail:+ / }返したパスの実体が無い: $leak_path"
    [ "$leak_count" -eq 1 ] || leak_ok=0 leak_detail="${leak_detail}${leak_detail:+ / }\$TMPDIR に残ったファイルが $leak_count 件"
    [ "$leak_ok" -eq 1 ] && collect_ok "$leak_label" || collect_fail "$leak_label" "$leak_detail"

    # 判定記録TSV の可読性は、対象文書パスや題材集合ディレクトリと同じく引数の検査で押さえる。
    local uj_dir="$BATS_TEST_TMPDIR/unreadable-judgments"
    local uj_label="47. report（判定記録TSV を読めない）→ exit 2、判定記録TSV を名指しする（期待帰結の側へ化けない）"
    mkdir -p "$uj_dir"
    cp "$JUDGMENTS_DIR/valid-judgments.tsv" "$uj_dir/j.tsv"
    chmod 000 "$uj_dir/j.tsv"
    if [ -r "$uj_dir/j.tsv" ]; then
        # root 実行等で読めてしまう環境では成立しない検査なので、その旨を告知して飛ばす
        collect_skipped "$uj_label" "chmod 000 でも読める環境のため未実行"
    else
        local uj_ok=1 uj_detail=""
        sc report "$uj_dir/j.tsv" "$CASES_DIR/valid"
        [ "$status" -eq 2 ] || uj_ok=0 uj_detail="exit code 期待 2 / 実際 $status"
        case "$output" in
            *"判定記録TSV を読めない"*) ;;
            *) uj_ok=0 uj_detail="${uj_detail}${uj_detail:+ / }判定記録TSV を名指ししていない" ;;
        esac
        case "$output" in
            *"期待帰結"*) uj_ok=0 uj_detail="${uj_detail}${uj_detail:+ / }診断が期待帰結の側へ化けている" ;;
        esac
        [ "$uj_ok" -eq 1 ] && collect_ok "$uj_label" || collect_fail "$uj_label" "$uj_detail"
    fi
    # 復元に失敗しても collect_finish まで到達させる（内訳の報告を落とさない）。
    # bats の tmpdir 掃除のためにパーミッションは戻す必要があるが、被テスト側が
    # ファイルを消していれば chmod は空振りする。
    chmod 644 "$uj_dir/j.tsv" 2>/dev/null || true

    collect_finish
}
