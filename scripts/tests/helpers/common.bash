#!/usr/bin/env bash
# bats スイート共通のヘルパ。scripts/tests/*.bats はすべてこれを load して使う。
#
# ここが固定する型は4つ。個別の .bats はこれを再実装しない。
#
#   1. パス解決            — REPO_ROOT / PLUGIN_ROOT / FIXTURES_DIR
#   2. 検査器の起動の型    — bats 組み込みの `run` を既定とする（後述）
#   3. 共有 setup_file     — SUT / CORPORA / PRECONDITION_PATHS の引き渡し契約
#   4. 収集型ヘルパ        — collect_* 一式（1件目で打ち切らず全件を報告する）
#
# 【検査器の起動の型】
# bats は setup_file も @test 本体も errexit 下で実行する。意図的に exit 1 する検査器を
# `out=$(bash "$SUT" "$corpus")` のように素直に呼ぶと、その時点でケースが abort し、
# 以降の反復も集約報告も走らない。移行対象 fixture の大半（invalid/*）は exit 1 を期待
# するため、素直な実装は初手で全滅する。
# したがって検査器の起動は、場所を問わず bats 組み込みの `run`（`$status` / `$output`）で
# 行う。`run` が扱いづらい場面（複数コマンドのパイプライン・`run` の入れ子）に限り
# `set +e` で囲み、`set -e` の復帰を同一ブロック内で必ず行う。
# 検査器全体を起動する形は run_sut、検査器を読み込んで単一の検査単位だけを起動する形は
# run_sut_layer が持つ。後者も部分シェル越しの `run` であり、この型から外れない。
#
# 【setup_file を絶対に失敗させない理由】
# bats は setup_file が失敗するとそのファイルの全ケースを `not ok N setup_file failed` の
# 1件へ潰す。報告総数が失敗の有無で変動し、総数固定（AC5）とケース間の失敗非波及（AC4）に
# 直接反する。よって common_setup_file は判定を一切行わず、常に return 0 で終わる。
# 前提不成立（corpus 不在・検査器不在）は記録するだけにし、判定は各 .bats が1件だけ持つ
# 前提不成立ケース（assert_preconditions_met）が行う。

bats_require_minimum_version 1.5.0

# ---- 1. パス解決 ----
# BATS_TEST_DIRNAME は .bats の置かれた scripts/tests/。setup_file / @test の双方で有効。
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/adr"
FIXTURES_DIR="$REPO_ROOT/scripts/fixtures"

# ---- 3. 共有 setup_file と引き渡し契約 ----
#
# 各 .bats はファイル冒頭で対象を変数として宣言し、setup_file から common_setup_file を呼ぶ。
#
#   SUT                — 既定で起動する被テスト検査器の絶対パス（省略可）
#   CORPORA            — `<キー>|<corpus の絶対パス>[|<検査器の絶対パス>]` の配列（省略可）
#                        キーは退避ファイル名になるため、英数字・ハイフン・アンダースコアのみ。
#                        第3フィールドを省くと SUT を使う。
#   PRECONDITION_PATHS — 存在していなければならないパスの配列（省略可）
#
# CORPORA を空にすれば起動はスキップされる。corpus が @test ごとに固有で事前起動を共有
# できない場合はこの経路を使い、ケース内で `run` により直接起動する。

# 前提不成立を記録する。判定はしない。
record_precondition() {
    printf '%s\n' "$1" >>"$BATS_FILE_TMPDIR/preconditions"
}

common_setup_file() {
    : >"$BATS_FILE_TMPDIR/preconditions"

    if [ -n "${SUT:-}" ] && [ ! -f "$SUT" ]; then
        record_precondition "被テスト検査器が無い: $SUT"
    fi

    local path
    for path in ${PRECONDITION_PATHS[@]+"${PRECONDITION_PATHS[@]}"}; do
        [ -e "$path" ] || record_precondition "前提のパスが無い: $path"
    done

    local entry key rest corpus sut
    for entry in ${CORPORA[@]+"${CORPORA[@]}"}; do
        key="${entry%%|*}"
        rest="${entry#*|}"
        corpus="${rest%%|*}"
        if [ "$rest" = "$corpus" ]; then
            sut="${SUT:-}"
        else
            sut="${rest#*|}"
        fi

        if [ -z "$sut" ] || [ ! -f "$sut" ]; then
            record_precondition "検査器が無い（key=$key）: $sut"
            continue
        fi
        if [ ! -e "$corpus" ]; then
            record_precondition "corpus が無い（key=$key）: $corpus"
            continue
        fi

        run bash "$sut" "$corpus"
        printf '%s' "$output" >"$BATS_FILE_TMPDIR/$key.out"
        printf '%s' "$status" >"$BATS_FILE_TMPDIR/$key.rc"
    done

    return 0
}

# 退避結果の読み出し。未起動のキーは MISSING を返し、判定側で読める失敗にする。
sut_rc() {
    local f="$BATS_FILE_TMPDIR/$1.rc"
    if [ -f "$f" ]; then cat "$f"; else printf 'MISSING'; fi
}

sut_out() {
    local f="$BATS_FILE_TMPDIR/$1.out"
    if [ -f "$f" ]; then cat "$f"; else printf 'MISSING'; fi
}

# 各 .bats が1件だけ持つ前提不成立ケースの本体。
assert_preconditions_met() {
    local f="$BATS_FILE_TMPDIR/preconditions"
    if [ ! -f "$f" ]; then
        printf '前提の記録ファイルが無い（setup_file が走っていない）: %s\n' "$f" >&2
        return 1
    fi
    if [ -s "$f" ]; then
        printf '前提が満たされていません:\n' >&2
        sed 's/^/  - /' "$f" >&2
        return 1
    fi
    return 0
}

# 被テスト検査器を引数付きで起動する。結果は bats の $status / $output に入る
# （`run` は既定で stderr を stdout へ併合する）。stdin は明示的に閉じ、検査器が
# 誤って端末入力を待つことを防ぐ。
run_sut() {
    run bash "$SUT" "$@" </dev/null
}

# 被テスト検査器を読み込んで、単一の検査単位（レイヤ関数）だけを起動する。
# 事実の収集（collect_scan_targets / collect_facts）は済ませたうえで指定の1単位のみを呼び、
# その単位の違反出力と違反件数を観測する。結果は $status / $output に入る。
#
# 読み込みは**部分シェル経由**で行う。ケース内で直接読み込むと検査器の `set -euo pipefail`
# が bats 本体のシェルへ漏れ、nounset の下で収集型ヘルパの空配列参照が異常終了しうる。
# 部分シェルなら観測できるのは出力と終了コードだけになり、連想配列の中身などの内部状態は
# 見られない。この代償を受け入れたうえで、レイヤ間に検査の依存が無いことを外から確かめる。
#
# 引数: $1 レイヤ関数名 / $2 corpus のパス
run_sut_layer() {
    local layer="$1" corpus="$2"
    run bash -c '
        set -euo pipefail
        # shellcheck disable=SC1090
        source "$1"
        violations=0
        collect_scan_targets "$2"
        collect_facts
        if [ "$3" = "check_layer1_frontmatter_schema" ]; then
            "$3"
        else
            "$3" "$2"
        fi
        printf "[violations=%s]\n" "$violations"
    ' _ "$SUT" "$corpus" "$layer" </dev/null
}

# 直前の run_sut の exit code を、渡されたラベルで収集する。
collect_rc() {
    local expect="$1" label="$2"
    if [ "$status" -eq "$expect" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "exit $expect を期待したが $status / output: $output"
    fi
    return 0
}

# ---- 4. 収集型ヘルパ ----
#
# 欠落を1件目で打ち切らず配列へ貯め、collect_finish で全件を1メッセージへ整形する。
# これが「複数の欠落を1回の実行ですべて報告する」（AC4）を満たす手段である。
# ラベルは旧ランナーの [PASS] ラベルをそのまま引き継ぐ（移行等価性の突き合わせ対象）。

collect_init() {
    COLLECT_FAILURES=()
    COLLECT_LABELS=()
}

# 検査項目が通ったことを記録する。失敗しない。
collect_ok() {
    COLLECT_LABELS+=("$1")
    return 0
}

# 失敗を1件バッファへ積む。ここでは return せず、呼び出し側のループも中断しない。
collect_fail() {
    local label="$1" detail="${2-}"
    COLLECT_LABELS+=("$label")
    COLLECT_FAILURES+=("$label${detail:+ -- $detail}")
    return 0
}

# 旧 assert_equals に対応する収集版。
collect_equals() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "expected \"$expected\" but got \"$actual\""
    fi
    return 0
}

# 旧 assert_contains に対応する収集版。
collect_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        collect_ok "$label"
    else
        collect_fail "$label" "期待する部分文字列が出力に無い: $needle"
    fi
    return 0
}

# 旧 assert_not_contains に対応する収集版。
collect_not_contains() {
    local haystack="$1" needle="$2" label="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        collect_ok "$label"
    else
        collect_fail "$label" "出力に現れてはならない部分文字列がある: $needle"
    fi
    return 0
}

# 環境の都合で成立しない検査を、合格として数えつつ TAP のコメント channel（FD 3）へ
# 明示する。`collect_ok` だけでは成功時に何も出力されず、検査が告知なく消える
# （root 実行や chmod の効かないファイルシステムでは権限依存の検査が該当する）。
# bats の `skip` は @test 全体を打ち切るため、収集型のケース内では使えない。
collect_skipped() {
    local label="$1" reason="$2"
    printf '# skipped: %s（%s）\n' "$label" "$reason" >&3
    collect_ok "$label"
    return 0
}

# バッファが空なら成功、1件以上あれば全件を1メッセージへ整形して非0を返す。
# 各 @test の末尾で必ず呼ぶ。
collect_finish() {
    local n=${#COLLECT_FAILURES[@]}
    [ "$n" -eq 0 ] && return 0

    printf '%d/%d 件の検査項目が失敗しました（全件を列挙する）:\n' \
        "$n" "${#COLLECT_LABELS[@]}" >&2
    local item
    for item in "${COLLECT_FAILURES[@]}"; do
        printf '  [FAIL] %s\n' "$item" >&2
    done
    return 1
}
