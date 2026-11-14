#!/usr/bin/env bats
# adr プラグインの設定のうち、ADR ディレクトリのキー（adr-dir）のテスト。対象は、それを読む
# lint-adr.sh・gen-adr-index.sh・next-adr-id.sh と commit ゲートである。
#
# 固定するのは次の6つである。
#   - 単体のスクリプトは、引数を省くと adr-dir の値（無ければ既定の docs/adr）を対象にする。
#     値は、カレントディレクトリから決めた git のトップレベルからの相対パスとして読む
#   - 引数を渡せば、adr-dir より引数が優先する
#   - git のトップレベルを決められなければ、カレントディレクトリからの相対パスとして読む
#   - adr-dir の値の誤り（絶対パス・`..` を含む）は、ADR を検査せずに exit 2 で止まる
#   - commit ゲートは、index の検査ではステージした設定の adr-dir、作業ツリーの検査では
#     作業ツリーの設定の adr-dir を対象にする
#   - 既定の docs/adr は、同梱の既定値のファイルの adr-dir が持つ
#
# 検出の側（キーが指すディレクトリの違反で止まる）と、免除の側（キーが指さない docs/adr の違反では
# 止まらない）を対で置く。前者だけでは「docs/adr とキーの両方を検査する」変異が赤にならない。
# 値の誤りについても、adr-dir だけを書いた設定を語の群の一部とみなさないことを対で置く。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# 設定はリポジトリごとに置くため、ケースごとに一時ディレクトリへ git リポジトリを組み立てる。
# よって共有 setup_file の CORPORA は空にし、起動はケース内で `run` により行う。

load 'helpers/common'

LINT="$PLUGIN_ROOT/scripts/lint-adr.sh"
GEN_INDEX="$PLUGIN_ROOT/scripts/gen-adr-index.sh"
NEXT_ID="$PLUGIN_ROOT/scripts/next-adr-id.sh"
GATE="$PLUGIN_ROOT/hooks/adr-commit-gate"
VALID="$FIXTURES_DIR/lint-adr/valid/01-mixed-validity"
INVALID="$FIXTURES_DIR/lint-adr/invalid/01-status-missing"
INVALID_MESSAGE="status が空です"
EN_CONFIG="$FIXTURES_DIR/adr-config/en/config"
EN_VALID="$FIXTURES_DIR/adr-config/en/valid"
CONFIG_ERROR_MESSAGE="adr プラグインの設定に誤りがあります"
KEY_DIR="architecture/decisions"
TS="203104091530"
CORPORA=()
unset ADR_CONFIG_ROOT
PRECONDITION_PATHS=("$LINT" "$GEN_INDEX" "$NEXT_ID" "$GATE" "$VALID" "$INVALID" "$EN_CONFIG" "$EN_VALID")

setup_file() {
    common_setup_file
    command -v git >/dev/null 2>&1 || record_precondition "git が PATH に無い"
    command -v jq >/dev/null 2>&1 || record_precondition "jq が PATH に無い"
    return 0
}

# 一時ディレクトリに git リポジトリを作り、パスを REPO へ入れる。引数2 以降は
# `<トップレベルからの相対パス>=<ADR 群>` の組で、ADR 群をその場所へ置く。
make_repo() {
    local name="$1" spec rel corpus
    shift
    REPO="$BATS_TEST_TMPDIR/$name"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    for spec in "$@"; do
        rel="${spec%%=*}"
        corpus="${spec#*=}"
        mkdir -p "$(dirname "$REPO/$rel")"
        cp -R "$corpus" "$REPO/$rel"
    done
}

# 引数1 のディレクトリの .claude/adr/config へ、引数2 以降の行を書く（引数が1つなら設定を消す）。
write_config() {
    local dir="$1"
    shift
    rm -f "$dir/.claude/adr/config"
    [ "$#" -gt 0 ] || return 0
    mkdir -p "$dir/.claude/adr"
    printf '%s\n' "$@" >"$dir/.claude/adr/config"
}

# 引数1 のディレクトリで、引数2 のスクリプトを引数3 以降の引数で起動する。git の探索は
# 一時ディレクトリの内側で打ち切る（外側のリポジトリへ遡ると、git の外の経路を検査できない）。
run_in() {
    local dir="$1" script="$2"
    shift 2
    run env -u ADR_CONFIG_ROOT GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" ADR_TIMESTAMP="$TS" \
        bash -c 'cd "$1" && shift && bash "$@"' _ "$dir" "$script" "$@" </dev/null
}

commit_all() {
    git -C "$1" add -A
    git -C "$1" -c user.name=test -c user.email=test@example.invalid \
        -c commit.gpgsign=false commit -q -m init
}

# ゲートを、引数1 のリポジトリで引数2 のコマンドについて起動する。
run_gate() {
    local repo="$1" command="$2" input tmpdir="$BATS_TEST_TMPDIR/gate-tmp"
    mkdir -p "$tmpdir"
    input="$(jq -cn --arg c "$command" --arg d "$repo" '{tool_input: {command: $c}, cwd: $d}')"
    run env -u ADR_CONFIG_ROOT -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
        CLAUDE_PROJECT_DIR="$repo" GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" TMPDIR="$tmpdir" \
        bash -c 'cd "$1" && printf "%s" "$2" | bash "$3"' _ "$repo" "$input" "$GATE"
}

@test "前提: 被テスト検査器・ADR 群・必要なコマンドが揃っている" {
    assert_preconditions_met
}

@test "面①: 引数を省くと、adr-dir が指すディレクトリを対象にする" {
    collect_init

    # キーが指す側は適合し、既定の docs/adr は違反する
    make_repo key-valid "$KEY_DIR=$VALID" "docs/adr=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$LINT"
    collect_rc 0 "lint-adr.sh は adr-dir の ADR 群を検査し、docs/adr の違反を報告しない"
    run_in "$REPO" "$GEN_INDEX"
    collect_rc 0 "gen-adr-index.sh は exit 0"
    collect_equals "$output" "$(cat "$REPO/$KEY_DIR/index.md")" "gen-adr-index.sh は adr-dir の ADR 群の index を出す"

    # キーが指す側が違反すれば、違反として報告する（キーを読まない変異を赤にする）
    make_repo key-invalid "$KEY_DIR=$INVALID" "docs/adr=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$LINT"
    collect_rc 1 "lint-adr.sh は adr-dir の ADR 群の違反で exit 1"
    collect_contains "$output" "$INVALID_MESSAGE" "adr-dir の ADR 群の違反を報告する"
    collect_contains "$output" "$REPO/$KEY_DIR/" "違反の報告は adr-dir のディレクトリを指す"

    # next-adr-id.sh は adr-dir の既存 ADR を列挙する
    make_repo key-next "$KEY_DIR=$VALID" "docs/adr=$VALID"
    : >"$REPO/$KEY_DIR/ADR-$TS-01-seed.md"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$NEXT_ID"
    collect_rc 0 "next-adr-id.sh は exit 0"
    collect_equals "$output" "ADR-$TS-02" "next-adr-id.sh は adr-dir の既存 ADR から連番を決める"

    # 末尾の / は落として読む
    write_config "$REPO" "adr-dir: $KEY_DIR/"
    run_in "$REPO" "$NEXT_ID"
    collect_equals "$output" "ADR-$TS-02" "adr-dir の末尾の / を許す"

    collect_finish
}

@test "面②: adr-dir の値と既定の docs/adr は、git のトップレベルからの相対パスとして読む" {
    collect_init

    make_repo rel-key "$KEY_DIR=$INVALID" "docs/adr=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    mkdir -p "$REPO/sub/deeper"
    run_in "$REPO/sub/deeper" "$LINT"
    collect_rc 1 "サブディレクトリから起動しても、トップレベルからの adr-dir を検査する"
    collect_contains "$output" "$REPO/$KEY_DIR/" "サブディレクトリから起動しても、トップレベルの adr-dir を指す"

    # キーが無ければ、トップレベルの docs/adr を対象にする
    make_repo rel-default "docs/adr=$INVALID"
    mkdir -p "$REPO/sub"
    run_in "$REPO/sub" "$LINT"
    collect_rc 1 "キーが無ければ、サブディレクトリから起動してもトップレベルの docs/adr を検査する"
    collect_contains "$output" "$INVALID_MESSAGE" "トップレベルの docs/adr の違反を報告する"

    # 語の群だけを書いた設定でも、キーが無ければ docs/adr を対象にする
    make_repo rel-words-only "docs/adr=$EN_VALID"
    cp "$EN_CONFIG" "$REPO/en-config"
    mkdir -p "$REPO/.claude/adr"
    mv "$REPO/en-config" "$REPO/.claude/adr/config"
    run_in "$REPO" "$LINT"
    collect_rc 0 "語の群だけの設定では、docs/adr を語の群の値で検査する"

    # adr-dir が入れ子のリポジトリの中を指しても、語の群はカレントディレクトリのトップレベルの
    # 設定で読む（ADR ディレクトリから設定を解決し直して、入れ子の側の既定値へずれない）
    make_repo rel-nested "nested/adr=$EN_VALID"
    git -C "$REPO/nested" init -q
    mkdir -p "$REPO/.claude/adr"
    { cat "$EN_CONFIG"; printf 'adr-dir: nested/adr\n'; } >"$REPO/.claude/adr/config"
    run_in "$REPO" "$LINT"
    collect_rc 0 "入れ子のリポジトリの中の adr-dir でも、トップレベルの設定の語で検査する"
    run_in "$REPO" "$GEN_INDEX"
    collect_equals "${lines[1]:-}" "# Active ADR Index" "gen-adr-index.sh も、トップレベルの設定の語を使う"

    collect_finish
}

@test "面③: 引数を渡せば、adr-dir より引数が優先する" {
    collect_init

    make_repo arg-wins "$KEY_DIR=$VALID" "docs/adr=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$LINT" docs/adr
    collect_rc 1 "lint-adr.sh は引数の docs/adr を検査する（adr-dir は適合）"
    run_in "$REPO" "$GEN_INDEX" docs/adr
    collect_equals "$output" "$(cat "$REPO/docs/adr/index.md")" "gen-adr-index.sh は引数の ADR 群の index を出す"

    make_repo arg-wins-reverse "$KEY_DIR=$INVALID" "docs/adr=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$LINT" docs/adr
    collect_rc 0 "lint-adr.sh は引数の docs/adr を検査し、adr-dir の違反を報告しない"

    : >"$REPO/$KEY_DIR/ADR-$TS-01-seed.md"
    run_in "$REPO" "$NEXT_ID" docs/adr
    collect_equals "$output" "ADR-$TS-01" "next-adr-id.sh は引数の ADR ディレクトリから連番を決める"

    collect_finish
}

@test "面④: git の外では、カレントディレクトリからの相対パスとして読む" {
    collect_init

    local plain="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$plain/docs"
    cp -R "$INVALID" "$plain/docs/adr"
    # git の外では導入先の設定を読まない（置いてあっても adr-dir を使わない）
    mkdir -p "$plain/$KEY_DIR"
    cp -R "$VALID"/. "$plain/$KEY_DIR/"
    write_config "$plain" "adr-dir: $KEY_DIR"
    run_in "$plain" "$LINT"
    collect_rc 1 "git の外では、カレントディレクトリの docs/adr を検査する"
    collect_contains "$output" "docs/adr/" "git の外では、既定の docs/adr をカレントディレクトリから読む"

    # ADR_CONFIG_ROOT が明示したトップレベルからの相対パスとして読む（ゲートとテストの内部の経路）
    local root="$BATS_TEST_TMPDIR/root"
    mkdir -p "$root/$KEY_DIR"
    cp -R "$INVALID"/. "$root/$KEY_DIR/"
    write_config "$root" "adr-dir: $KEY_DIR"
    run env ADR_CONFIG_ROOT="$root" GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" \
        bash -c 'cd "$1" && bash "$2"' _ "$plain" "$LINT" </dev/null
    collect_rc 1 "ADR_CONFIG_ROOT の adr-dir を、そのトップレベルからの相対パスとして読む"
    collect_contains "$output" "$root/$KEY_DIR/" "ADR_CONFIG_ROOT のトップレベルの adr-dir を指す"

    collect_finish
}

@test "面⑤: adr-dir の値の誤りは exit 2 で止まり、adr-dir だけの設定は誤りにしない" {
    collect_init

    local value needle
    make_repo bad-value "docs/adr=$VALID"
    for value in "/abs/adr|が絶対パスです" "../outside|を含みます" "docs/../adr|を含みます"; do
        needle="${value#*|}"
        value="${value%%|*}"
        write_config "$REPO" "adr-dir: $value"
        run_in "$REPO" "$LINT"
        collect_rc 2 "adr-dir: $value で lint-adr.sh は exit 2"
        collect_contains "$output" "$CONFIG_ERROR_MESSAGE" "adr-dir: $value を設定の誤りとして示す"
        collect_contains "$output" "$needle" "adr-dir: $value の原因を示す"
        # 引数を渡しても、設定の誤りは誤りとして止める
        run_in "$REPO" "$LINT" docs/adr
        collect_rc 2 "adr-dir: $value は、引数を渡しても exit 2"
    done

    # 名前に .. を含むが、.. という要素ではない値は誤りにしない
    make_repo dotted-name "x..y=$VALID"
    write_config "$REPO" "adr-dir: x..y"
    run_in "$REPO" "$LINT"
    collect_rc 0 "要素としての .. でなければ誤りにしない"

    # 語の群と独立に置ける（adr-dir だけの設定は、語の群の一部だけを書いた設定ではない）
    make_repo only-key "$KEY_DIR=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_in "$REPO" "$LINT"
    collect_rc 0 "adr-dir だけの設定は、語の群を既定値で読む"
    collect_not_contains "$output" "語の群の一部だけ" "adr-dir を語の群に数えない"

    # 語の群と一緒に置いても読む
    make_repo words-and-key "$KEY_DIR=$EN_VALID"
    mkdir -p "$REPO/.claude/adr"
    { cat "$EN_CONFIG"; printf 'adr-dir: %s\n' "$KEY_DIR"; } >"$REPO/.claude/adr/config"
    run_in "$REPO" "$LINT"
    collect_rc 0 "語の群と adr-dir を両方書いた設定で、adr-dir の ADR 群を語の群の値で検査する"

    collect_finish
}

@test "面⑥: adr-dir が指すディレクトリが無ければ、どの設定から決めたかを示して exit 2 で止まる" {
    collect_init

    local script
    make_repo missing-dir "docs/adr=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    for script in "$LINT" "$GEN_INDEX" "$NEXT_ID"; do
        run_in "$REPO" "$script"
        collect_rc 2 "$(basename "$script") は exit 2"
        collect_contains "$output" "ディレクトリが見つかりません: $REPO/$KEY_DIR" "$(basename "$script") は決めたディレクトリを示す"
        collect_contains "$output" "$REPO/.claude/adr/config の adr-dir" "$(basename "$script") はどの設定から決めたかを示す"
    done

    collect_finish
}

@test "面⑦: commit ゲートは、ステージした設定の adr-dir が指すディレクトリを検査する" {
    collect_init

    # 受入条件: キーで architecture/decisions を指したリポジトリで、壊れた ADR があれば止める
    make_repo gate-invalid "$KEY_DIR=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 2 "adr-dir の ADR 群の違反で commit を止める"
    collect_contains "$output" "ステージした内容（index）の $KEY_DIR が drift-lint に違反しています" \
        "止めた対象として adr-dir のディレクトリを示す"
    collect_contains "$output" "$INVALID_MESSAGE" "adr-dir の ADR 群の違反を報告する"

    # キーが指さない docs/adr の違反では止めない
    make_repo gate-valid "$KEY_DIR=$VALID" "docs/adr=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 0 "adr-dir の ADR 群が適合すれば、docs/adr の違反があっても通す"

    # 末尾の / は落として読む（検査の対象と報告に / を重ねない）
    make_repo gate-trailing-slash "$KEY_DIR=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR/"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 2 "末尾に / を付けた adr-dir でも、その ADR 群の違反で止める"
    collect_contains "$output" "ステージした内容（index）の $KEY_DIR が drift-lint" "末尾の / を落とした値で検査する"

    # キーが無ければ、今と同じく docs/adr を検査する
    make_repo gate-default "docs/adr=$INVALID"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 2 "キーが無ければ docs/adr の違反で止める"
    collect_contains "$output" "ステージした内容（index）の docs/adr" "キーが無ければ docs/adr を検査する"

    # キーが指すディレクトリが index に無ければ、ADR を使っていないものとして通す
    make_repo gate-noop "docs/adr=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 0 "adr-dir が指すディレクトリが無ければ no-op で通す"
    collect_equals "$output" "" "no-op は何も出力しない"

    # ステージした設定の adr-dir の誤りは、検査する場所を決められないので止める
    make_repo gate-bad-value "docs/adr=$VALID"
    write_config "$REPO" "adr-dir: ../outside"
    git -C "$REPO" add -A
    run_gate "$REPO" "git commit -m x"
    collect_rc 2 "ステージした設定の adr-dir の誤りで止める"
    collect_contains "$output" "ステージした設定から ADR ディレクトリを決められません" "止めた理由が示される"
    collect_contains "$output" "を含みます" "adr-dir の誤りの原因が示される"

    collect_finish
}

@test "面⑧: index の検査はステージした設定、作業ツリーの検査は作業ツリーの設定の adr-dir を使う" {
    collect_init

    # ステージした設定は adr-dir を指し、作業ツリーの設定だけが docs/adr へ戻した状態
    make_repo gate-staged-key "$KEY_DIR=$VALID" "docs/adr=$INVALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    commit_all "$REPO"
    write_config "$REPO" "adr-dir: docs/adr"
    run_gate "$REPO" "git commit -m x"
    collect_rc 0 "index の検査は、作業ツリーの設定ではなくステージした設定の adr-dir を使う"

    run_gate "$REPO" "git commit -a -m x"
    collect_rc 2 "作業ツリーも検査するときは、作業ツリーの設定の adr-dir（docs/adr）の違反で止める"
    collect_contains "$output" "作業ツリーの docs/adr が drift-lint に違反しています" "作業ツリーの設定が指すディレクトリを示す"
    collect_not_contains "$output" "ステージした内容（index）" "ステージした設定が指す側は適合する"

    # 作業ツリーにだけある設定は、index の検査に使わない（既定の docs/adr を検査する）
    make_repo gate-unstaged-key "$KEY_DIR=$VALID" "docs/adr=$INVALID"
    git -C "$REPO" add -A
    write_config "$REPO" "adr-dir: $KEY_DIR"
    run_gate "$REPO" "git commit -m x"
    collect_rc 2 "設定をステージしていなければ、index の検査は既定の docs/adr を対象にする"
    collect_contains "$output" "ステージした内容（index）の docs/adr" "既定の docs/adr を検査したことを示す"

    # 作業ツリーの adr-dir のディレクトリの未ステージの違反で止める
    make_repo gate-worktree "$KEY_DIR=$VALID"
    write_config "$REPO" "adr-dir: $KEY_DIR"
    commit_all "$REPO"
    rm -rf "${REPO:?}/$KEY_DIR"
    cp -R "$INVALID" "$REPO/$KEY_DIR"
    run_gate "$REPO" "git commit -m x"
    collect_rc 0 "index をそのまま commit するなら、作業ツリーの adr-dir の違反では止めない"
    run_gate "$REPO" "git commit -a -m x"
    collect_rc 2 "ステージを変えうるなら、作業ツリーの adr-dir の違反で止める"
    collect_contains "$output" "作業ツリーの $KEY_DIR が drift-lint に違反しています" "作業ツリーの adr-dir を示す"

    collect_finish
}

# 既定の docs/adr の正本は同梱の既定値のファイルである。既定値のファイルが adr-dir を欠くと、
# 引数を省いた全スクリプトとゲートが対象を決められない。その破損を、既存テストの大量の失敗では
# なく1件の失敗として示す。
@test "面⑨: 同梱の既定値が adr-dir を docs/adr として持ち、欠ければ原因を示して止まる" {
    collect_init

    run bash -c 'source "$1"; adr_config_load "" && printf "%s\n" "$ADR_CONFIG_ADR_DIR"' \
        _ "$PLUGIN_ROOT/scripts/adr-config.sh" </dev/null
    collect_rc 0 "同梱の既定値を誤りなく読める"
    collect_equals "$output" "docs/adr" "同梱の既定値の adr-dir は docs/adr"

    local copy="$BATS_TEST_TMPDIR/plugin-copy"
    cp -R "$PLUGIN_ROOT" "$copy"
    sed -i.orig '/^adr-dir:/d' "$copy/scripts/adr-config.default"
    make_repo default-missing-key "docs/adr=$VALID"
    run_in "$REPO" "$copy/scripts/lint-adr.sh"
    collect_rc 2 "既定値のファイルが adr-dir を欠けば exit 2"
    collect_contains "$output" "同梱の既定値に正しい adr-dir がありません" "既定値のファイルの破損を原因として示す"

    collect_finish
}
