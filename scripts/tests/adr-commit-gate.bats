#!/usr/bin/env bats
# adr プラグインの commit ゲート（plugins/adr/hooks/adr-commit-gate）と、ゲートが起動する
# drift-lint（plugins/adr/scripts/lint-adr.sh）の実行環境の前提のテスト。
#
# ゲートについて固定するのは、検査対象のツリーの解決である。
#   - コミットが実際に走る git コンテキスト（PreToolUse の JSON の cwd → フックの cwd →
#     CLAUDE_PROJECT_DIR の順）から解決し、worktree からの commit で project root 側を
#     検査しない
#   - docs/adr が無いことによる no-op と、コミット対象を特定できないことを区別し、後者を
#     通さない
# 検出の側（worktree の違反で止まる）だけでなく、その逆（project root 側の違反では止まらない）
# も対で置く。前者だけでは「両方のツリーを検査する」変異が赤にならない。
#
# lint について固定するのは、bash 4.2 未満で原因を示して exit 2 で止まることである。
# BASH_VERSINFO は書き換えられないため、BASH_VERSION を差し替えたシェルで lint を読み込み、
# 版の判定のブロックだけを通す（lint は読み込み時に検査本体を走らせない）。
# 4.2 以上で正しく動くことは、他の lint のテストが実際の bash で走らせて担う。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# ゲートの検査対象はケースごとに一時ディレクトリへ組み立てる git リポジトリであり、共有できない。
# よって共有 setup_file の CORPORA は空にし、起動はケース内で `run` により行う。

load 'helpers/common'

SUT="$PLUGIN_ROOT/hooks/adr-commit-gate"
LINT_ADR="$PLUGIN_ROOT/scripts/lint-adr.sh"
VALID_CORPUS="$FIXTURES_DIR/lint-adr/valid/02-xref-valid"
INVALID_CORPUS="$FIXTURES_DIR/lint-adr/invalid/01-status-missing"
INVALID_MESSAGE="status が空です"
UNRESOLVED_MESSAGE="コミット対象のリポジトリを特定できません"
BASH_VERSION_MESSAGE="bash 4.2 以上を必要とします"
CORPORA=()
PRECONDITION_PATHS=("$LINT_ADR" "$VALID_CORPUS" "$INVALID_CORPUS")

setup_file() {
    common_setup_file
    # JSON の cwd を読む経路は jq を要する。jq が無いと JSON の cwd を読めず、面①が
    # 理由の読めない失敗になるため、前提として記録する。
    command -v jq >/dev/null 2>&1 || record_precondition "jq が PATH に無い"
    command -v git >/dev/null 2>&1 || record_precondition "git が PATH に無い"
    return 0
}

# 一時ディレクトリに git リポジトリを作り、ADR 群（引数2。省略時は docs/adr を置かない）を
# docs/adr として commit する。作ったリポジトリのパスを返す。
make_repo() {
    local name="$1" corpus="${2-}"
    local dir="$BATS_TEST_TMPDIR/$name"
    mkdir -p "$dir"
    git -C "$dir" init -q
    if [ -n "$corpus" ]; then
        mkdir -p "$dir/docs"
        cp -R "$corpus" "$dir/docs/adr"
    else
        : >"$dir/README.md"
    fi
    git -C "$dir" add -A
    git -C "$dir" -c user.name=test -c user.email=test@example.invalid \
        -c commit.gpgsign=false commit -q -m init
    printf '%s' "$dir"
}

# 引数1 のリポジトリから worktree を作り、その docs/adr を引数2 の ADR 群で置き換える
# （作業ツリー上の変更のまま。ゲートは commit 前の作業ツリーを検査する）。
make_worktree() {
    local main="$1" corpus="$2"
    local dir="$BATS_TEST_TMPDIR/wt-$(basename "$main")"
    git -C "$main" worktree add -q "$dir" -b "wt-$(basename "$main")"
    rm -rf "$dir/docs/adr"
    cp -R "$corpus" "$dir/docs/adr"
    printf '%s' "$dir"
}

make_plain_dir() {
    local dir="$BATS_TEST_TMPDIR/$1"
    mkdir -p "$dir"
    printf '%s' "$dir"
}

# PreToolUse の入力を組み立てる。引数2 が空なら cwd を載せない。
hook_input() {
    local command="$1" cwd="${2-}"
    if [ -n "$cwd" ]; then
        jq -cn --arg c "$command" --arg d "$cwd" '{tool_input: {command: $c}, cwd: $d}'
    else
        jq -cn --arg c "$command" '{tool_input: {command: $c}}'
    fi
}

# ゲートを起動する。引数: フックの cwd / stdin へ渡す入力 / CLAUDE_PROJECT_DIR（`-` なら未設定）
# git の探索は一時ディレクトリの内側で打ち切る。外側（テストを走らせているリポジトリ等）へ
# 遡って解決すると、「特定できない」経路を検査できなくなる。
run_gate() {
    local hook_cwd="$1" input="$2" project_dir="$3"
    # env は `-u` を代入より前にしか受け付けない
    local -a env_args=(-u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE)
    if [ "$project_dir" = "-" ]; then
        env_args+=(-u CLAUDE_PROJECT_DIR)
    else
        env_args+=("CLAUDE_PROJECT_DIR=$project_dir")
    fi
    env_args+=("GIT_CEILING_DIRECTORIES=$BATS_TEST_TMPDIR")
    run env "${env_args[@]}" bash -c 'cd "$1" && printf "%s" "$2" | bash "$3"' \
        _ "$hook_cwd" "$input" "$SUT"
}

@test "前提: 被テスト検査器・ADR 群・必要なコマンドが揃っている" {
    assert_preconditions_met
}

@test "面①: worktree からの commit は、JSON の cwd が指す worktree の docs/adr を検査する" {
    collect_init

    local main wt
    main="$(make_repo main-valid "$VALID_CORPUS")"
    wt="$(make_worktree "$main" "$INVALID_CORPUS")"
    run_gate "$main" "$(hook_input "git commit -m x" "$wt")" "$main"
    collect_rc 2 "worktree 側の違反で止まる（フックの cwd と CLAUDE_PROJECT_DIR は project root）"
    collect_contains "$output" "$INVALID_MESSAGE" "worktree 側の違反が報告される"

    main="$(make_repo main-invalid "$INVALID_CORPUS")"
    wt="$(make_worktree "$main" "$VALID_CORPUS")"
    run_gate "$main" "$(hook_input "git commit -m x" "$wt")" "$main"
    collect_rc 0 "project root 側の違反では止まらない（worktree 側は適合）"

    collect_finish
}

@test "面②: JSON に cwd が無いときは、フックの cwd から解決する" {
    collect_init

    local main wt
    main="$(make_repo main-valid "$VALID_CORPUS")"
    wt="$(make_worktree "$main" "$INVALID_CORPUS")"
    run_gate "$wt" "$(hook_input "git commit -m x")" "$main"
    collect_rc 2 "フックの cwd の worktree 側の違反で止まる"
    collect_contains "$output" "$INVALID_MESSAGE" "worktree 側の違反が報告される"

    main="$(make_repo main-invalid "$INVALID_CORPUS")"
    wt="$(make_worktree "$main" "$VALID_CORPUS")"
    run_gate "$wt" "$(hook_input "git commit -m x")" "$main"
    collect_rc 0 "CLAUDE_PROJECT_DIR 側の違反では止まらない"

    collect_finish
}

@test "面③: JSON の cwd とフックの cwd が git 外なら、CLAUDE_PROJECT_DIR へ戻る" {
    collect_init

    local repo outside
    repo="$(make_repo repo-invalid "$INVALID_CORPUS")"
    outside="$(make_plain_dir outside)"
    run_gate "$outside" "$(hook_input "git commit -m x" "$outside")" "$repo"
    collect_rc 2 "CLAUDE_PROJECT_DIR のリポジトリの違反で止まる"
    collect_contains "$output" "$INVALID_MESSAGE" "CLAUDE_PROJECT_DIR のリポジトリの違反が報告される"

    collect_finish
}

@test "面④: docs/adr が無いことによる no-op と、コミット対象を特定できないことを区別する" {
    collect_init

    local repo outside
    repo="$(make_repo repo-no-adr)"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "コミット対象のリポジトリに docs/adr が無ければ通す"
    collect_equals "$output" "" "no-op は何も出力しない"

    # コミット対象に docs/adr が無いとき、別の候補の docs/adr を検査しない
    local other
    other="$(make_repo other-invalid "$INVALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$other"
    collect_rc 0 "コミット対象に docs/adr が無ければ、CLAUDE_PROJECT_DIR 側の違反を検査しない"

    outside="$(make_plain_dir outside)"
    run_gate "$outside" "$(hook_input "git commit -m x" "$outside")" "$outside"
    collect_rc 2 "どの候補も git 外なら止める"
    collect_contains "$output" "$UNRESOLVED_MESSAGE" "特定できない理由が示される"

    run_gate "$outside" "$(hook_input "git commit -m x")" "-"
    collect_rc 2 "JSON に cwd が無く CLAUDE_PROJECT_DIR も未設定で、フックの cwd が git 外なら止める"
    collect_contains "$output" "$UNRESOLVED_MESSAGE" "特定できない理由が示される（候補が1つだけの場合）"

    collect_finish
}

@test "面⑤: git commit でないコマンドは検査しない" {
    collect_init

    local repo
    repo="$(make_repo repo-invalid "$INVALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git status" "$repo")" "$repo"
    collect_rc 0 "違反のある ADR 群でも、git commit でなければ通す"

    collect_finish
}

@test "面⑥: lint-adr.sh は bash 4.2 未満で原因を示して exit 2 で止まる" {
    collect_init

    local version
    # 空は bash 以外のシェルで走らせた場合（BASH_VERSION が無い）に当たる
    for version in "3.2.57(1)-release" "4.1.17(1)-release" ""; do
        run bash -c 'BASH_VERSION="$1"; . "$2" || { echo "rc=$?"; exit 0; }; echo "rc=0"' \
            _ "$version" "$LINT_ADR"
        collect_contains "$output" "rc=2" "版 \"$version\" では exit 2 で止まる"
        collect_contains "$output" "$BASH_VERSION_MESSAGE" "版 \"$version\" では必要な版が示される"
    done

    # 境界の 4.2 と現行の版では、版の判定を通過する
    for version in "4.2.53(1)-release" "5.2.21(1)-release" "10.0.0(1)-release"; do
        run bash -c 'BASH_VERSION="$1"; . "$2" || { echo "rc=$?"; exit 0; }; echo "rc=0"' \
            _ "$version" "$LINT_ADR"
        collect_contains "$output" "rc=0" "版 \"$version\" では版の判定を通過する"
        collect_not_contains "$output" "$BASH_VERSION_MESSAGE" "版 \"$version\" では版の不足を報告しない"
    done

    collect_finish
}
