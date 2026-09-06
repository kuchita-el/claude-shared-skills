#!/usr/bin/env bash
# 全スイート runner。commit ゲート（scripts/hooks/pre-commit-gate.sh）から呼ばれ、
# テストスイートと検査器をまとめて実行する。
#
# 設計上の要点:
# - いずれかが失敗しても残りを最後まで実行してから非0で終わる。失敗を1回の実行で出揃わせる
# - 成功したスイートの出力は畳み、失敗したスイートの出力だけを展開する
# - bats を解決できない場合は成功扱いにせず非0で終わる（fail-closed）。スキップして成功に
#   すると検査が一度も走らないまま commit が通り、しかも警告が出ない
# - 唯一の例外が claude-plugin-validate である。実体が外部 CLI（claude）であり、利用者が
#   各自の方法で既に導入している。mise の npm backend で版を固定する経路は形式上あるが、
#   採ると手元の claude を mise 管理下の別実体でシャドウすることになるため採らない
#   （固定できないのではなく、固定しない選択である）。解決できない場合は SKIPPED として
#   理由を展開し、集計行にも skipped を出したうえで緑にする
# - ただし skip を無条件に許すと、CI が claude を導入し損ねた場合に「一度も走らないまま
#   緑」になる。担保として RUN_TESTS_REQUIRE_ALL_SUITES=1 を用意し、これが立っている
#   環境では前提不成立を skip ではなく失敗として扱う。CI はこの値を立てて runner を呼ぶ
# - 引数でスイートを1本に絞れる（開発時の反復用。既定は全実行）
#
# 実行ガイド: docs/development/test-execution.md
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT" || exit 1

# スイート定義: <名前>|<種別>。実体は run_one() が持つ。
# 種別は出力ラベルにのみ使う（test = テストスイート / check = 検査器）。
SUITES=(
    "bats|test"
    "validate-skills|check"
    "validate-plugin-manifests|check"
    "validate-plugin-portability|check"
    "validate-plugin-path-references|check"
    "claude-plugin-validate|check"
)

TESTS_DIR="$REPO_ROOT/scripts/tests"

# 前提不成立を skip ではなく失敗として扱うか。CI はこれを立てて呼ぶ（冒頭コメント参照）。
# 値域は 1 / 0 / 未設定に限り、それ以外の値は理由を出して落とす。true・yes を黙って
# 「skip 可」と解釈すると、要求モードのつもりで立てた運用者が、検査が一度も走らないまま
# 緑を受け取る。担保の有無が値の綴りで静かに変わる状態を作らない（掛かるのは値だけで、
# 変数名を取り違えた場合は未設定と区別がつかない）。
REQUIRE_ALL_SUITES="${RUN_TESTS_REQUIRE_ALL_SUITES:-0}"

usage() {
    cat <<'USAGE'
usage: bash scripts/run-tests.sh [スイート名]

  引数なし    全スイートを実行する（commit ゲートが呼ぶ形）
  スイート名  そのスイートだけを実行する（開発時の反復用）
  --list      スイート名の一覧を出す

bats スイートをさらに絞りたい場合は bats を直接呼ぶ:
  mise exec -- bats scripts/tests/<name>.bats
USAGE
}

list_suites() {
    local entry
    for entry in "${SUITES[@]}"; do
        printf '%s\n' "${entry%%|*}"
    done
}

# bats の解決。版固定を効かせるため mise exec を優先し、mise を使わない環境のために
# PATH をフォールバックとして残す。どちらでも解決できなければ非0で終わる。
BATS_CMD=()
resolve_bats() {
    if command -v mise >/dev/null 2>&1 && mise exec -- bats --version >/dev/null 2>&1; then
        BATS_CMD=(mise exec -- bats)
        return 0
    fi
    if command -v bats >/dev/null 2>&1; then
        BATS_CMD=(bats)
        return 0
    fi
    cat >&2 <<'MSG'
run-tests: bats を解決できません（mise exec・PATH のいずれでも見つからない）
  導入: mise install   （リポジトリ直下の mise.toml が版を固定する）
  信頼: mise trust     （チェックアウトごとに一度。未信頼のまま mise は設定を読まない）
MSG
    return 1
}

# 実行すべき .bats の期待リスト。glob だけで組み立てると、ファイルが消えても glob が
# 静かに縮小するだけで検査が素通りする（76→67 ケースでも「all suites passed」になる）。
# これは #645 の発端——検知機構は正しいのに走らせる経路が無い——と同型の穴であり、
# 対象を変えて runner 側に再生産される。期待リストを固定し、glob 結果と**双方向で**
# 突き合わせる（`manage-adr-surface.bats` が同梱スクリプトの参照ファイルに対して採るのと
# 同じ方式）。テストファイルを増減させたときは本リストと実行ガイド §1 のスイート表を
# 更新する（§7 の移行対応表は移行完了時点の凍結記録であり、追随の対象ではない）。
EXPECTED_BATS=(
    adr-portability.bats
    gen-adr-index.bats
    lint-adr-layers.bats
    lint-adr-stem.bats
    lint-adr-xref.bats
    lint-domain-doc.bats
    local-plugin-runners.bats
    manage-adr-surface.bats
    next-adr-id.bats
    plugin-manifests.bats
    plugin-path-references.bats
    run-tests-runner.bats
    skill-portability.bats
    dev-workflow-skill-contract.bats
    dev-workflow-fixture-contract.bats
    plan-norm-regression.bats
    behavior-invariants.bats
    authoring-reference-relocation.bats
    plugin-boundaries.bats
    writing-lint.bats
    writing-contract.bats
    distribution-boundary.bats
)

BATS_FILES=()
collect_bats_files() {
    local f base name problems=()

    local -a actual=()
    for f in "$TESTS_DIR"/*.bats; do
        [ -f "$f" ] && actual+=("$(basename "$f")")
    done

    # 期待リストにあって実在しないもの（＝消えたファイル）
    for name in "${EXPECTED_BATS[@]}"; do
        case " ${actual[*]-} " in
            *" $name "*) BATS_FILES+=("$TESTS_DIR/$name") ;;
            *) problems+=("期待するテストファイルが無い: $name") ;;
        esac
    done

    # 実在して期待リストに無いもの（＝登録し忘れ。そのファイルは一度も走らない）
    for base in ${actual[@]+"${actual[@]}"}; do
        case " ${EXPECTED_BATS[*]} " in
            *" $base "*) ;;
            *) problems+=("期待リストに未登録のテストファイル: $base") ;;
        esac
    done

    if [ "${#problems[@]}" -gt 0 ]; then
        echo "run-tests: $TESTS_DIR の構成が期待リストと一致しません" >&2
        for f in "${problems[@]}"; do
            echo "  - $f" >&2
        done
        echo "  増減が意図したものなら scripts/run-tests.sh の EXPECTED_BATS を更新してください" >&2
        return 1
    fi
    return 0
}

# スイート固有の前提。満たさない場合だけ理由を1行出力する（無出力＝前提を満たす）。
# 判定を run_one の終了コードへ載せないのは、claude-plugin-validate の実体が外部 CLI で
# あり、その終了コードの値域を本リポジトリが決められないためである。特定の値を skip の
# 合図に充てると、CLI が同じ値で失敗したときに実失敗が skip へ化ける。
suite_precondition_failure() {
    case "$1" in
        claude-plugin-validate)
            command -v claude >/dev/null 2>&1 && return 0
            echo "claude を PATH 上に解決できない（導入: npm install -g @anthropic-ai/claude-code）"
            ;;
    esac
}

run_one() {
    case "$1" in
        bats) "${BATS_CMD[@]}" --print-output-on-failure "${BATS_FILES[@]}" ;;
        validate-skills) bash scripts/validate-skills.sh ;;
        validate-plugin-manifests) bash scripts/validate-plugin-manifests.sh . ;;
        validate-plugin-portability) bash scripts/validate-plugin-portability.sh . ;;
        validate-plugin-path-references) bash scripts/validate-plugin-path-references.sh . docs/development/plugin-path-reference-ledger.md ;;
        # 非 strict で呼ぶ。--strict は version フィールドの欠落を含む警告をエラーへ昇格
        # させるが、本リポジトリは版をコミット SHA へ委ねており version を持たない
        # （ADR-202609061416-01）。
        claude-plugin-validate) claude plugin validate . ;;
        *)
            echo "run-tests: 実体が未定義のスイートです: $1" >&2
            return 1
            ;;
    esac
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    --list)
        list_suites
        exit 0
        ;;
esac

case "$REQUIRE_ALL_SUITES" in
    0 | 1) ;;
    *)
        echo "run-tests: RUN_TESTS_REQUIRE_ALL_SUITES は 1 か 0 のみ受け付けます（受領値: '$REQUIRE_ALL_SUITES'）" >&2
        exit 1
        ;;
esac

filter="${1:-}"
if [ -n "$filter" ]; then
    if ! list_suites | grep -qxF "$filter"; then
        echo "run-tests: 未知のスイート名です: $filter" >&2
        echo "  一覧: bash scripts/run-tests.sh --list" >&2
        exit 1
    fi
fi

if [ -z "$filter" ] || [ "$filter" = "bats" ]; then
    resolve_bats || exit 1
    collect_bats_files || exit 1
fi

work_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$work_dir"' EXIT

failed_names=()
skipped_names=()
ran=0
start_all=$SECONDS

for entry in "${SUITES[@]}"; do
    name="${entry%%|*}"
    kind="${entry#*|}"

    [ -z "$filter" ] || [ "$filter" = "$name" ] || continue

    precondition_failure=$(suite_precondition_failure "$name")
    if [ -n "$precondition_failure" ]; then
        ran=$((ran + 1))
        if [ "$REQUIRE_ALL_SUITES" = "1" ]; then
            printf '[%-5s] %-20s ... FAILED (前提不成立)\n' "$kind" "$name"
            printf '    %s| %s\n' "$name" "$precondition_failure"
            printf '    %s| RUN_TESTS_REQUIRE_ALL_SUITES=1 のため前提不成立を失敗として扱う\n' "$name"
            failed_names+=("$name")
        else
            printf '[%-5s] %-20s ... SKIPPED\n' "$kind" "$name"
            printf '    %s| %s\n' "$name" "$precondition_failure"
            skipped_names+=("$name")
        fi
        continue
    fi

    log="$work_dir/$name.log"
    start=$SECONDS
    run_one "$name" >"$log" 2>&1
    rc=$?
    elapsed=$((SECONDS - start))
    ran=$((ran + 1))

    # bats が計画件数と実行件数の食い違いを報告した場合は非0へ倒す。0件実行が緑に見える
    # 失敗（GNU parallel 不在で bats -j を使った場合に実際に起きる）を通さないため。
    if [ "$name" = "bats" ] && [ "$rc" -eq 0 ] &&
        grep -q 'Executed .* instead of expected' "$log"; then
        rc=1
    fi

    # 上のガードは bats 自身が食い違いを報告した場合しか効かない。TAP のプラン行と実際の
    # 報告件数を runner 側でも突き合わせ、0件実行や件数不足が緑に見えることを防ぐ。
    if [ "$name" = "bats" ] && [ "$rc" -eq 0 ]; then
        planned=$(sed -n 's/^1\.\.\([0-9][0-9]*\)$/\1/p' "$log" | head -1)
        reported=$(grep -c '^ok \|^not ok ' "$log")
        if [ -z "$planned" ] || [ "$planned" -eq 0 ] || [ "$planned" -ne "$reported" ]; then
            echo "run-tests: bats のプラン行と報告件数が一致しません（plan=${planned:-無し} / reported=$reported）" >&2
            rc=1
        fi
    fi

    if [ "$rc" -eq 0 ]; then
        if [ "$name" = "bats" ]; then
            printf '[%-5s] %-20s ... %s (%ds)\n' "$kind" "$name" \
                "$(grep -c '^ok ' "$log") tests, 0 failures" "$elapsed"
        else
            printf '[%-5s] %-20s ... ok (%ds)\n' "$kind" "$name" "$elapsed"
        fi
    else
        printf '[%-5s] %-20s ... FAILED (exit %d, %ds)\n' "$kind" "$name" "$rc" "$elapsed"
        failed_names+=("$name")
        # 失敗したスイートの出力のみ展開する。行頭にスイート名を添えて出所を明示する。
        # bats は TAP で通過ケースも1行ずつ出すため、成功行だけは畳む（プラン行・失敗行・
        # 診断行は残す）。ゲート経由では stderr だけが渡るので、埋もれさせない。
        if [ "$name" = "bats" ]; then
            grep -v '^ok ' "$log" | sed "s/^/    $name| /"
        else
            sed "s/^/    $name| /" "$log"
        fi
    fi
done

elapsed_all=$((SECONDS - start_all))

if [ "$ran" -eq 0 ]; then
    echo "run-tests: 実行対象のスイートがありません" >&2
    exit 1
fi

skipped_note=""
if [ "${#skipped_names[@]}" -gt 0 ]; then
    skipped_note="; skipped: ${skipped_names[*]}"
fi

if [ "${#failed_names[@]}" -eq 0 ]; then
    printf 'all suites passed (%d suites, %ds%s)\n' "$ran" "$elapsed_all" "$skipped_note"
    exit 0
fi

printf 'FAILED: %d/%d suites (%ds%s) -- %s\n' \
    "${#failed_names[@]}" "$ran" "$elapsed_all" "$skipped_note" "${failed_names[*]}"
exit 1
