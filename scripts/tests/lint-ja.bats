#!/usr/bin/env bats
# 日本語文書の機械検査（plugins/writing/scripts/lint-ja.sh）のテスト。
#
# scripts/fixtures/lint-ja/{valid,invalid}/*.md を検査し、valid は exit 0、
# invalid は exit 1 と期待メッセージ部分一致を検査する。加えて、種別プロファイルの
# 閾値・既定の入力単位（差分）・変更行を含む文のファイル本体からの復元を検査する。
#
# fixture 名は静的な配列として列挙する。ディレクトリを走査して動的に列挙すると
# 登録ケース数が入力で変動し、報告総数が固定でなくなる（lint-domain-doc.bats と同じ方針）。
#
# 検査対象の fixture は既定の入力単位（差分）ではなく `--all` で回す。差分を既定に
# したまま単体のファイルを渡すと、その fixture が差分に現れないため常に緑になり、
# 判定が素通りする。差分そのものの挙動は面④・面⑤が一時リポジトリを作って検査する。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"

# CORPORA は使わない。共通の setup_file はオプション無しで検査器を起動するため、
# `--all` を伴う本スイートの起動形と合わない。各ケース内で run_sut を直接呼ぶ。
CORPORA=()
PRECONDITION_PATHS=(
    "$LINT_FIXTURES/valid"
    "$LINT_FIXTURES/invalid"
    "$LINT_FIXTURES/profile/type-profiles.md"
    "$REPO_ROOT/plugins/writing/scripts/allowlist"
)

VALID_FIXTURES=(
    "01-plain.md"
    "02-code-block-ignored.md"
    "03-identifier-in-inline-code-with-note.md"
    "04-backticks-not-counted.md"
    "05-kanji-compound-not-checked.md"
    "06-inline-code-not-ungrounded.md"
)

# <ファイル名>|<出力に含まれることを期待する文字列（コロン区切りで AND 検査）>
INVALID_FIXTURES=(
    "01-sentence-too-long.md|一文の長さ"
    "02-ungrounded-english.md|未接地語:retention"
    "03-ungrounded-katakana.md|未接地語:ファセット"
    "04-bare-identifier.md|不透明な識別子:ADR-202606040737-01"
    "05-identifier-in-inline-code-bare.md|不透明な識別子:ADR-202606040737-01"
    "06-sentence-across-lines.md|一文の長さ"
    "07-paren-inner-period.md|一文の長さ"
)

setup_file() {
    common_setup_file
}

# fixture を静的に列挙する以上、ディレクトリへ足しただけのファイルは登録されるまで
# 一度も検査されない。登録漏れを検査項目として検出する（lint-domain-doc.bats と同型）。
collect_fixture_coverage() {
    local subdir="$1" registered="$2"
    local prev_nullglob present f base label
    prev_nullglob="$(shopt -p nullglob || true)"
    shopt -s nullglob
    present=("$LINT_FIXTURES/$subdir"/*.md)
    eval "$prev_nullglob"

    for f in ${present[@]+"${present[@]}"}; do
        base="$(basename "$f")"
        label="$subdir fixture が登録されている: $base"
        case " $registered " in
            *" $base "*) collect_ok "$label" ;;
            *) collect_fail "$label" "配列へ未登録のため一度も検査されない" ;;
        esac
    done
    return 0
}

# 一時 git リポジトリを作る。差分を入力単位とする検査は git を要するため、
# 面④・面⑤はこの上で行う。コミット者情報は環境に依存させない。
init_temp_repo() {
    local dir="$1"
    mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email "test@example.invalid"
    git -C "$dir" config user.name "lint-ja test"
}

commit_all() {
    local dir="$1" msg="$2"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "$msg"
}

# 指定したディレクトリを作業ディレクトリにして検査器を起動する。差分の基点となる
# リポジトリは作業ディレクトリから解決されるため、この経路でのみ差分の挙動を検査できる。
run_sut_in() {
    local dir="$1"
    shift
    pushd "$dir" >/dev/null || return 1
    run bash "$SUT" "$@" </dev/null
    popd >/dev/null || return 1
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

@test "面①: valid fixture がいずれも exit 0" {
    collect_init

    local base label
    for base in "${VALID_FIXTURES[@]}"; do
        label="valid/$base (exit=0)"
        run_sut --all "$LINT_FIXTURES/valid/$base"
        if [ "$status" -eq 0 ]; then
            collect_ok "$label"
        else
            # 1件目で打ち切らない。壊れた fixture が複数あれば1回の実行で全件出す。
            collect_fail "$label" "expected exit=0, got=$status / output: $output"
        fi
    done

    collect_fixture_coverage valid "${VALID_FIXTURES[*]}"

    collect_finish
}

@test "面②: invalid fixture が期待診断つきで exit 1" {
    collect_init

    local entry base patterns label p missing ok registered=""
    for entry in "${INVALID_FIXTURES[@]}"; do
        base="${entry%%|*}"
        patterns="${entry#*|}"
        registered="$registered $base"
        label="invalid/$base (exit=1, msg matched)"

        run_sut --all "$LINT_FIXTURES/invalid/$base"

        ok=1
        missing=""
        local saved_ifs="$IFS"
        IFS=':'
        for p in $patterns; do
            if [[ "$output" != *"$p"* ]]; then
                ok=0
                missing="$p"
                break
            fi
        done
        IFS="$saved_ifs"

        if [ "$status" -eq 1 ] && [ "$ok" -eq 1 ]; then
            collect_ok "$label"
        else
            collect_fail "$label" \
                "expected exit=1 with \"$patterns\", got exit=$status (missing=\"$missing\") / output: $output"
        fi
    done

    collect_fixture_coverage invalid "$registered"

    collect_finish
}

@test "面③: 種別プロファイルの一文長の上限が共通規約の既定より優先する" {
    collect_init

    local doc="$LINT_FIXTURES/profile/between-60-and-100.md"
    local profile="$LINT_FIXTURES/profile/type-profiles.md"

    # 既定（汎用・上限100字）では通る。
    run_sut --all --profile "$profile" "$doc"
    collect_rc 0 "汎用プロファイルでは exit 0"

    # 種別「規約」（上限60字）では一文の長さで落ちる。
    run_sut --all --profile "$profile" --type 規約 "$doc"
    collect_rc 1 "種別 規約 では exit 1"
    collect_contains "$output" "一文の長さ" "種別 規約 で一文の長さが報告される"

    # 未登録の種別は既定へフォールバックする。黙って落ちない。
    run_sut --all --profile "$profile" --type 存在しない種別 "$doc"
    collect_rc 0 "未登録の種別は既定へフォールバックして exit 0"

    collect_finish
}

@test "面④: 既定の入力単位が差分であり、ファイル全体の検査は --all でのみ行われる" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/diff-default"
    init_temp_repo "$repo"

    # 既に違反を含む文書をコミットしておく（既存文書に相当する）。
    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/doc.md"
    commit_all "$repo" "既存の違反を含む文書"

    # 触れたのは違反を含まない段落だけにする。
    printf '\n新しく足した段落はいずれの検出項目にも当たらない。\n' >>"$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 0 "差分が既定: 触れていない既存の違反は報告しない"

    run_sut_in "$repo" --all doc.md
    collect_rc 1 "--all: ファイル全体の既存の違反を報告する"
    collect_contains "$output" "一文の長さ" "--all で一文の長さが報告される"

    collect_finish
}

@test "面⑤: 変更行を含む文をファイル本体から復元してから判定する" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/restore"
    init_temp_repo "$repo"

    # 1つの文を3行へ分けて置く。各行は単独では上限に収まる。
    {
        printf '# 復元の検査\n\n'
        printf '検査の対象となる文書は、書き手が書いた内容をそのまま保つ形で保存されており、\n'
        printf '読み手が最初から最後まで順に読み進めたときに意味を取れるかどうかを\n'
        printf '確かめる必要があるため、ここでは一文を三つの行へ分けて書いてある。\n'
    } >"$repo/doc.md"
    commit_all "$repo" "複数行にまたがる一文"

    # 差分のハンクに載るのは真ん中の1行だけにする。その行は単独では上限に収まる。
    sed -i 's/意味を取れるかどうかを/意味を正しく取れるかどうかを/' "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 1 "ハンクに載らない前後の行を含めて一文として判定する"
    collect_contains "$output" "一文の長さ" "復元後の長さで一文の長さが報告される"

    collect_finish
}
