#!/usr/bin/env bats
# adr プラグインの commit ゲート（plugins/adr/hooks/adr-commit-gate）と、ゲートが起動する
# drift-lint（plugins/adr/scripts/lint-adr.sh）の実行環境の前提のテスト。
#
# ゲートについて固定するのは、検査対象のツリーの解決と、検査する内容の選び方である。
#   - コミットが実際に走る git コンテキスト（PreToolUse の JSON の cwd → フックの cwd →
#     CLAUDE_PROJECT_DIR の順）から解決し、worktree からの commit で project root 側を
#     検査しない
#   - docs/adr が無いことによる no-op と、コミット対象を特定できないことを区別し、後者を
#     通さない
#   - ステージした内容（index）のブロブを、改行変換を通さずに検査する。コマンドがステージを
#     変えうるときは、作業ツリーも併せて検査する。作業ツリーが index と同じなら、作業ツリーの
#     検査を重ねない
#   - index を取り出せないときは通さず、取り出した一時ディレクトリを残さない
#   - 設定ファイル（.claude/adr/config）は、検査する側の版を読む（index の検査ではステージした版、
#     作業ツリーの検査では作業ツリーの版）。一時ディレクトリを含む別のリポジトリの設定や、
#     ゲートの環境に残った ADR_CONFIG_ROOT を読まない
# 検出の側（worktree の違反で止まる）だけでなく、その逆（project root 側の違反では止まらない）
# も対で置く。前者だけでは「両方のツリーを検査する」変異が赤にならない。検査する内容についても、
# index の違反で止まる側と、作業ツリーだけの違反では止まらない側を対で置く。
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
STAGED_MESSAGE="ステージした内容（index）の docs/adr が drift-lint に違反しています"
WORKTREE_MESSAGE="作業ツリーの docs/adr が drift-lint に違反しています"
CONFIG_FIXTURES="$FIXTURES_DIR/adr-config"
EN_CONFIG="$CONFIG_FIXTURES/en/config"
EN_VALID="$CONFIG_FIXTURES/en/valid"
EN_CONFIG_ERROR="$CONFIG_FIXTURES/errors/partial-words/config"
# 既定値（日本語）の語で英語の ADR 群を検査したときに出る違反の一部
EN_UNDER_DEFAULT_MESSAGE='"Accepted"'
CONFIG_ERROR_MESSAGE="adr プラグインの設定に誤りがあります"
BASH_VERSION_MESSAGE="bash 4.2 以上を必要とします"
CORPORA=()
PRECONDITION_PATHS=("$LINT_ADR" "$VALID_CORPUS" "$INVALID_CORPUS" "$EN_CONFIG" "$EN_VALID" "$EN_CONFIG_ERROR")

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

# 引数1 のディレクトリの docs/adr を、引数2 の ADR 群で置き換える（空なら docs/adr を消す）。
replace_adr() {
    local dir="$1" corpus="${2-}"
    rm -rf "$dir/docs/adr"
    if [ -n "$corpus" ]; then
        mkdir -p "$dir/docs"
        cp -R "$corpus" "$dir/docs/adr"
    fi
}

# 引数1 のリポジトリから worktree を作り、その docs/adr を引数2 の ADR 群で置き換えてステージする
# （index と作業ツリーが一致する。ここで固定するのは検査対象のツリーの解決である）。
make_worktree() {
    local main="$1" corpus="$2"
    local dir="$BATS_TEST_TMPDIR/wt-$(basename "$main")"
    git -C "$main" worktree add -q "$dir" -b "wt-$(basename "$main")"
    replace_adr "$dir" "$corpus"
    git -C "$dir" add -A docs/adr
    printf '%s' "$dir"
}

# 適合する ADR 群を commit したリポジトリを作り、index の docs/adr を引数2 の ADR 群、
# 作業ツリーの docs/adr を引数3 の ADR 群にする（空なら、その側に docs/adr を置かない）。
make_staged_repo() {
    local name="$1" staged="${2-}" worktree="${3-}"
    local dir
    dir="$(make_repo "$name" "$VALID_CORPUS")"
    replace_adr "$dir" "$staged"
    git -C "$dir" add -A docs
    replace_adr "$dir" "$worktree"
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

# 引数1 のリポジトリの作業ツリーへ、引数2 の設定ファイルを置く（空なら設定ファイルを消す）。
place_config() {
    local dir="$1" config="${2-}"
    rm -f "$dir/.claude/adr/config"
    if [ -n "$config" ]; then
        mkdir -p "$dir/.claude/adr"
        cp "$config" "$dir/.claude/adr/config"
    fi
}

# ゲートを起動する。引数: フックの cwd / stdin へ渡す入力 / CLAUDE_PROJECT_DIR（`-` なら未設定）/
# TMPDIR（省略時はテストの一時ディレクトリの中に作る）
# ADR_CONFIG_ROOT は外す。配列 GATE_EXTRA_ENV があれば、その代入を環境へ足す。
# GATE_SUT があれば、同梱のゲートの代わりにそれを起動する。
# git の探索は一時ディレクトリの内側で打ち切る。外側（テストを走らせているリポジトリ等）へ
# 遡って解決すると、「特定できない」経路を検査できなくなる。
run_gate() {
    local hook_cwd="$1" input="$2" project_dir="$3" tmpdir="${4-}"
    if [ -z "$tmpdir" ]; then
        tmpdir="$BATS_TEST_TMPDIR/gate-tmp"
        mkdir -p "$tmpdir"
    fi
    # env は `-u` を代入より前にしか受け付けない
    local -a env_args=(-u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u ADR_CONFIG_ROOT)
    if [ "$project_dir" = "-" ]; then
        env_args+=(-u CLAUDE_PROJECT_DIR)
    else
        env_args+=("CLAUDE_PROJECT_DIR=$project_dir")
    fi
    env_args+=("GIT_CEILING_DIRECTORIES=$BATS_TEST_TMPDIR" "TMPDIR=$tmpdir")
    env_args+=(${GATE_EXTRA_ENV[@]+"${GATE_EXTRA_ENV[@]}"})
    run env "${env_args[@]}" bash -c 'cd "$1" && printf "%s" "$2" | bash "$3"' \
        _ "$hook_cwd" "$input" "${GATE_SUT:-$SUT}"
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

@test "面⑦: index をそのまま commit するコマンドでは、ステージした内容だけを検査する" {
    collect_init

    local repo command
    repo="$(make_staged_repo staged-invalid "$INVALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 2 "ステージした ADR が壊れていれば、作業ツリーの側が正しくても止まる"
    collect_contains "$output" "$STAGED_MESSAGE" "ステージした内容の違反であることが示される"
    collect_contains "$output" "$INVALID_MESSAGE" "ステージした内容の違反が報告される"

    repo="$(make_staged_repo staged-valid "$VALID_CORPUS" "$INVALID_CORPUS")"
    for command in "git commit -m x" "git commit -m \"two words\" --amend --no-edit" \
        "git commit -F msg.txt" "git commit -mx -s -q"; do
        run_gate "$repo" "$(hook_input "$command" "$repo")" "$repo"
        collect_rc 0 "ステージした ADR が正しければ、未ステージの側が壊れていても通す（$command）"
    done

    # 検査するのはブロブそのものであり、改行変換を通した後の内容ではない。
    # core.autocrlf=true では、取り出しで LF が CRLF に変わると lint の改行の検査に掛かる
    repo="$(make_staged_repo autocrlf "$VALID_CORPUS" "$VALID_CORPUS")"
    git -C "$repo" config core.autocrlf true
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "core.autocrlf=true でも、LF のブロブを変換せずに検査して通す"

    # 逆に、CRLF のブロブは CRLF のまま検査して止める
    local file
    repo="$(make_staged_repo crlf-blob "$VALID_CORPUS" "$VALID_CORPUS")"
    file="$(ls "$repo"/docs/adr/ADR-*.md | head -n 1)"
    sed 's/$/\r/' "$file" >"$file.crlf" && mv "$file.crlf" "$file"
    git -C "$repo" add docs/adr
    cp -R "$VALID_CORPUS"/. "$repo/docs/adr/"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 2 "CRLF のブロブは、作業ツリーの側が LF でも止める"
    collect_contains "$output" "改行コードが CRLF です" "CRLF のブロブの違反が報告される"

    collect_finish
}

@test "面⑧: ステージを変えうるコマンドでは、作業ツリーも併せて検査する" {
    collect_init

    local repo command
    repo="$(make_staged_repo staged-valid "$VALID_CORPUS" "$INVALID_CORPUS")"
    for command in "git commit -a -m x" "git commit -am x" "git commit --all -m x" \
        "git commit -i -m x docs/adr" "git commit -o -m x" "git commit -m x docs/adr" \
        "git commit -m x -- docs/adr" "git add docs/adr && git commit -m x" \
        "git add docs/adr; git commit -m x" 'git commit -m "$(printf x)"' \
        'git commit -m "unterminated'; do
        run_gate "$repo" "$(hook_input "$command" "$repo")" "$repo"
        collect_rc 2 "作業ツリーの違反で止まる（$command）"
        collect_contains "$output" "$WORKTREE_MESSAGE" "作業ツリーの違反であることが示される（$command）"
    done

    # 作業ツリーを併せて検査するときも、index の検査は外さない
    repo="$(make_staged_repo staged-invalid "$INVALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "ステージした ADR の違反で止まる（git commit -a）"
    collect_contains "$output" "$STAGED_MESSAGE" "ステージした内容の違反であることが示される（git commit -a）"

    # 作業ツリーが index と同じなら、作業ツリーの検査を重ねない（同じ違反を二度報告しない）
    repo="$(make_staged_repo both-invalid "$INVALID_CORPUS" "$INVALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "index と作業ツリーが同じ違反を持てば止まる"
    collect_contains "$output" "$STAGED_MESSAGE" "ステージした内容の違反が報告される"
    collect_not_contains "$output" "$WORKTREE_MESSAGE" "index と同じ作業ツリーは検査を重ねない"

    # 未追跡のファイルが1つでもあれば、index と同じとは扱わない
    repo="$(make_staged_repo extra-untracked "$VALID_CORPUS" "$VALID_CORPUS")"
    cp "$INVALID_CORPUS"/ADR-*.md "$repo/docs/adr/"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "未追跡の ADR の違反で止まる"
    collect_contains "$output" "$WORKTREE_MESSAGE" "作業ツリーの違反であることが示される（未追跡の ADR）"

    # 追跡中のファイルの未ステージの変更があれば、index と同じとは扱わない
    repo="$(make_staged_repo tracked-modified "$VALID_CORPUS" "$VALID_CORPUS")"
    printf 'stale\n' >>"$repo/docs/adr/index.md"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "追跡中のファイルの未ステージの違反で止まる"
    collect_contains "$output" "$WORKTREE_MESSAGE" "作業ツリーの違反であることが示される（追跡中のファイル）"

    repo="$(make_staged_repo both-valid "$VALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git add docs/adr && git commit -a -m x" "$repo")" "$repo"
    collect_rc 0 "index と作業ツリーがともに適合すれば通す"

    collect_finish
}

@test "面⑨: index に docs/adr が無く、未追跡の ADR だけがあるとき" {
    collect_init

    local repo
    repo="$(make_staged_repo untracked-only "" "$INVALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "index をそのまま commit するなら、ADR は commit されないので通す"
    collect_equals "$output" "" "no-op は何も出力しない"

    run_gate "$repo" "$(hook_input "git add -A && git commit -m x" "$repo")" "$repo"
    collect_rc 2 "ステージを変えうるなら、未追跡の ADR の違反で止まる"
    collect_contains "$output" "$WORKTREE_MESSAGE" "作業ツリーの違反であることが示される"

    collect_finish
}

@test "面⑩: index を取り出せなければ通さず、取り出した一時ディレクトリを残さない" {
    collect_init

    local repo tmpdir
    repo="$(make_staged_repo staged-valid "$VALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo" "$BATS_TEST_TMPDIR/no-such-dir"
    collect_rc 2 "一時ディレクトリを作れなければ止める"
    collect_contains "$output" "一時ディレクトリを作れません" "止めた理由が示される"

    # 未解決の衝突（index に stage 1〜3 の項目がある）は取り出せない
    local path blob
    path="$(git -C "$repo" ls-files -- docs/adr | head -n 1)"
    blob="$(git -C "$repo" rev-parse ":$path")"
    git -C "$repo" update-index --force-remove -- "$path"
    printf '100644 %s 1\t%s\n100644 %s 2\t%s\n100644 %s 3\t%s\n' \
        "$blob" "$path" "$blob" "$path" "$blob" "$path" | git -C "$repo" update-index --index-info
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 2 "index の docs/adr を取り出せなければ止める"
    collect_contains "$output" "ステージした docs/adr と設定ファイルを取り出せません" "止めた理由が示される"

    # 通した場合と止めた場合のどちらでも、一時ディレクトリを残さない
    tmpdir="$BATS_TEST_TMPDIR/cleanup-tmp"
    mkdir -p "$tmpdir"
    repo="$(make_staged_repo cleanup-valid "$VALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo" "$tmpdir"
    collect_rc 0 "適合する index は通す（後始末の確認の前提）"
    collect_equals "$(ls -A "$tmpdir")" "" "通した後に一時ディレクトリが残らない"
    repo="$(make_staged_repo cleanup-invalid "$INVALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo" "$tmpdir"
    collect_rc 2 "違反する index は止める（後始末の確認の前提）"
    collect_equals "$(ls -A "$tmpdir")" "" "止めた後に一時ディレクトリが残らない"

    # 設定ファイルの置き場を同梱の adr-config.sh から読めなければ、検査しないまま通さない
    local copy="$BATS_TEST_TMPDIR/plugin-copy"
    cp -R "$PLUGIN_ROOT" "$copy"
    rm -f "$copy/scripts/adr-config.sh"
    local GATE_SUT="$copy/hooks/adr-commit-gate"
    repo="$(make_staged_repo no-config-lib "$VALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 2 "adr-config.sh が無ければ止める"
    collect_contains "$output" "設定ファイルの置き場を adr-config.sh から読めません" "止めた理由が示される"

    collect_finish
}

@test "面⑪: 設定ファイルは、検査する側（index・作業ツリー）の版を読む" {
    collect_init

    local repo other
    # 英語の設定と英語の ADR 群をステージしたリポジトリ
    repo="$(make_staged_repo en-staged "$EN_VALID" "$EN_VALID")"
    place_config "$repo" "$EN_CONFIG"
    git -C "$repo" add .claude
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "英語の設定と英語の ADR 群をステージしていれば通す"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 0 "作業ツリーも併せて検査するときも、英語の設定で通す"

    # index の検査は、作業ツリーの設定ではなくステージした設定で判定する（両向き）
    place_config "$repo" "$EN_CONFIG_ERROR"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "作業ツリーの設定が壊れていても、ステージした設定で判定して通す"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "作業ツリーも検査するときは、作業ツリーの設定の誤りで止まる"
    collect_contains "$output" "$CONFIG_ERROR_MESSAGE" "作業ツリーの設定の誤りが報告される"

    repo="$(make_staged_repo en-unstaged-config "$EN_VALID" "$EN_VALID")"
    place_config "$repo" "$EN_CONFIG"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 2 "設定をステージしていなければ、作業ツリーに英語の設定があっても既定値で判定して止める"
    collect_contains "$output" "$STAGED_MESSAGE" "ステージした内容の違反であることが示される（既定値で判定）"
    collect_contains "$output" "$EN_UNDER_DEFAULT_MESSAGE" "既定値の語彙の違反が報告される"

    # TMPDIR が別の git リポジトリの中にあっても、そのリポジトリの設定を読まない
    other="$(make_repo other-en "$EN_VALID")"
    place_config "$other" "$EN_CONFIG"
    mkdir -p "$other/tmp"
    repo="$(make_staged_repo ja-tmpdir "$VALID_CORPUS" "$VALID_CORPUS")"
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo" "$other/tmp"
    collect_rc 0 "TMPDIR を含む別のリポジトリの英語の設定を読まず、既定値で判定して通す"

    # ゲートの環境に残った ADR_CONFIG_ROOT を、index の検査でも作業ツリーの検査でも使わない
    local -a GATE_EXTRA_ENV=("ADR_CONFIG_ROOT=$other")
    run_gate "$repo" "$(hook_input "git commit -m x" "$repo")" "$repo"
    collect_rc 0 "環境の ADR_CONFIG_ROOT を index の検査で使わない"
    replace_adr "$repo" "$VALID_CORPUS"
    printf 'stale\n' >>"$repo/docs/adr/index.md"
    git -C "$repo" add docs/adr
    cp "$VALID_CORPUS/index.md" "$repo/docs/adr/index.md"
    run_gate "$repo" "$(hook_input "git commit -a -m x" "$repo")" "$repo"
    collect_rc 2 "index の違反で止まる（作業ツリーの検査を省かない前提）"
    collect_not_contains "$output" "$WORKTREE_MESSAGE" "環境の ADR_CONFIG_ROOT を作業ツリーの検査で使わない"

    collect_finish
}
