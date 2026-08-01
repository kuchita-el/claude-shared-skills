#!/usr/bin/env bash
# 全スイート runner。commit ゲート（scripts/hooks/pre-commit-gate.sh）から呼ばれ、
# テストスイートと検査器をまとめて実行する。
#
# 設計上の要点:
# - いずれかが失敗しても残りを最後まで実行してから非0で終わる。失敗を1回の実行で出揃わせる
# - 成功したスイートの出力は畳み、失敗したスイートの出力だけを展開する
# - 引数でスイートを1本に絞れる（開発時の反復用。既定は全実行）
#
# 実行ガイド: docs/development/test-execution.md
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT" || exit 1

# スイート定義: <名前>|<種別>|<コマンド>
# 種別は出力ラベルにのみ使う（test = テストスイート / check = 検査器）。
SUITES=(
    "next-adr-id|test|bash scripts/test-next-adr-id.sh"
    "lint-domain-doc|test|bash scripts/test-lint-domain-doc.sh"
    "lint-adr|test|bash scripts/test-lint-adr.sh"
    "adr-scoping-cases|test|bash scripts/test-adr-scoping-cases.sh"
    "validate-skills|check|bash scripts/validate-skills.sh"
)

usage() {
    cat <<'USAGE'
usage: bash scripts/run-tests.sh [スイート名]

  引数なし    全スイートを実行する（commit ゲートが呼ぶ形）
  スイート名  そのスイートだけを実行する（開発時の反復用）
  --list      スイート名の一覧を出す
USAGE
}

list_suites() {
    local entry
    for entry in "${SUITES[@]}"; do
        printf '%s\n' "${entry%%|*}"
    done
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

filter="${1:-}"
if [ -n "$filter" ]; then
    if ! list_suites | grep -qxF "$filter"; then
        echo "run-tests: 未知のスイート名です: $filter" >&2
        echo "  一覧: bash scripts/run-tests.sh --list" >&2
        exit 1
    fi
fi

work_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$work_dir"' EXIT

failed_names=()
ran=0
start_all=$SECONDS

for entry in "${SUITES[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    kind="${rest%%|*}"
    command="${rest#*|}"

    [ -z "$filter" ] || [ "$filter" = "$name" ] || continue

    log="$work_dir/$name.log"
    start=$SECONDS
    # shellcheck disable=SC2086 # コマンドは本ファイル内の定義であり、単語分割を意図している
    bash -c "$command" >"$log" 2>&1
    rc=$?
    elapsed=$((SECONDS - start))
    ran=$((ran + 1))

    if [ "$rc" -eq 0 ]; then
        printf '[%-5s] %-20s ... ok (%ds)\n' "$kind" "$name" "$elapsed"
    else
        printf '[%-5s] %-20s ... FAILED (exit %d, %ds)\n' "$kind" "$name" "$rc" "$elapsed"
        failed_names+=("$name")
        # 失敗したスイートの出力のみ展開する。行頭にスイート名を添えて出所を明示する。
        sed "s/^/    $name| /" "$log"
    fi
done

elapsed_all=$((SECONDS - start_all))

if [ "$ran" -eq 0 ]; then
    echo "run-tests: 実行対象のスイートがありません" >&2
    exit 1
fi

if [ "${#failed_names[@]}" -eq 0 ]; then
    printf 'all suites passed (%d suites, %ds)\n' "$ran" "$elapsed_all"
    exit 0
fi

printf 'FAILED: %d/%d suites (%ds) -- %s\n' \
    "${#failed_names[@]}" "$ran" "$elapsed_all" "${failed_names[*]}"
exit 1
