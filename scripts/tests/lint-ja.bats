#!/usr/bin/env bats
# 日本語文書の機械検査（plugins/writing/scripts/lint-ja.sh）のテスト。
#
# scripts/fixtures/lint-ja/{valid,invalid,candidate}/*.md を検査し、valid は exit 0 かつ
# 無出力、invalid は exit 1 と期待メッセージ部分一致、candidate は exit 0 と候補の出力を
# 検査する。加えて、種別プロファイルの解決・既定の入力単位（差分）・判定の単位（文）・
# 入力が不正な場合の exit 2 を検査する。
#
# fixture 名は静的な配列として列挙する。ディレクトリを走査して動的に列挙すると
# 登録ケース数が入力で変動し、報告総数が固定でなくなる（lint-domain-doc.bats と同じ方針）。
#
# 検査対象の fixture は既定の入力単位（差分）ではなく `--all` で回す。差分を既定に
# したまま単体のファイルを渡すと、その fixture が差分に現れないため常に緑になり、
# 判定が素通りする。差分そのものの挙動は一時リポジトリを作る面が検査する。
#
# 種別プロファイルはすべての面で明示的に渡す。省略すると解決先が作業ディレクトリに
# 従属し、本リポジトリの `.claude/writing/type-profiles.md` を読む面と同梱既定を読む面へ
# 割れる。現在はどちらも100字に収束しているため露見しないが、プロジェクト側の値を
# 1つ変えるだけで実装を触らずに複数のケースが落ちる。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"
BUNDLED_PROFILE="$REPO_ROOT/plugins/writing/references/document-type-profiles.md"

# CORPORA は使わない。共通の setup_file はオプション無しで検査器を起動するため、
# `--all` を伴う本スイートの起動形と合わない。各ケース内で lint を直接呼ぶ。
CORPORA=()
PRECONDITION_PATHS=(
    "$LINT_FIXTURES/valid"
    "$LINT_FIXTURES/invalid"
    "$LINT_FIXTURES/candidate"
    "$LINT_FIXTURES/profile/type-profiles.md"
    "$BUNDLED_PROFILE"
)

VALID_FIXTURES=(
    "01-plain.md"
    "02-code-block-ignored.md"
    "03-identifier-in-inline-code-with-note.md"
    "04-backticks-not-counted.md"
    "05-link-not-counted.md"
    "06-tilde-fence-ignored.md"
    "07-indented-code-ignored.md"
    "08-sentence-delimiters.md"
    "09-codespan-symbols-inert.md"
)

# <ファイル名>|<出力に含まれることを期待する文字列（コロン区切りで AND 検査）>
INVALID_FIXTURES=(
    "01-sentence-too-long.md|一文の長さ"
    "02-sentence-across-lines.md|一文の長さ"
    "03-paren-inner-period.md|一文の長さ"
    "04-issue-number-at-line-start.md|一文の長さ"
)

# 候補は違反ではない。出力は出るが exit 0 で終わる。
CANDIDATE_FIXTURES=(
    "01-bare-identifier.md|候補: 不透明な識別子:ADR-202606040737-01"
    "02-identifier-in-inline-code-bare.md|候補: 不透明な識別子:ADR-202606040737-01"
    "03-issue-number.md|候補: 不透明な識別子:#684"
)

setup_file() {
    common_setup_file
}

# 種別プロファイルを明示して検査器を起動する。
lint() {
    run bash "$SUT" --profile "$BUNDLED_PROFILE" "$@" </dev/null
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

# 期待文字列（コロン区切り）がすべて出力に含まれるかを見る。
output_has_all() {
    local patterns="$1" p saved_ifs="$IFS"
    MISSING_PATTERN=""
    IFS=':'
    for p in $patterns; do
        if [[ "$output" != *"$p"* ]]; then
            MISSING_PATTERN="$p"
            IFS="$saved_ifs"
            return 1
        fi
    done
    IFS="$saved_ifs"
    return 0
}

# 一時 git リポジトリを作る。差分を入力単位とする検査は git を要するため、
# 差分まわりの面はこの上で行う。コミット者情報は環境に依存させない。
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
    run bash "$SUT" --profile "$BUNDLED_PROFILE" "$@" </dev/null
    popd >/dev/null || return 1
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

@test "面①: valid fixture がいずれも exit 0 かつ無出力" {
    collect_init

    local base label
    for base in "${VALID_FIXTURES[@]}"; do
        label="valid/$base (exit=0, 無出力)"
        lint --all "$LINT_FIXTURES/valid/$base"
        if [ "$status" -eq 0 ] && [ -z "$output" ]; then
            collect_ok "$label"
        else
            # 1件目で打ち切らない。壊れた fixture が複数あれば1回の実行で全件出す。
            collect_fail "$label" "expected exit=0 and empty output, got=$status / output: $output"
        fi
    done

    collect_fixture_coverage valid "${VALID_FIXTURES[*]}"

    collect_finish
}

@test "面②: invalid fixture が期待診断つきで exit 1" {
    collect_init

    local entry base patterns label registered=""
    for entry in "${INVALID_FIXTURES[@]}"; do
        base="${entry%%|*}"
        patterns="${entry#*|}"
        registered="$registered $base"
        label="invalid/$base (exit=1, msg matched)"

        lint --all "$LINT_FIXTURES/invalid/$base"

        if [ "$status" -eq 1 ] && output_has_all "$patterns"; then
            collect_ok "$label"
        else
            collect_fail "$label" \
                "expected exit=1 with \"$patterns\", got exit=$status (missing=\"$MISSING_PATTERN\") / output: $output"
        fi
    done

    collect_fixture_coverage invalid "$registered"

    collect_finish
}

@test "面③: candidate fixture が候補を出しつつ exit 0" {
    collect_init

    local entry base patterns label registered=""
    for entry in "${CANDIDATE_FIXTURES[@]}"; do
        base="${entry%%|*}"
        patterns="${entry#*|}"
        registered="$registered $base"
        label="candidate/$base (exit=0, 候補が出る)"

        lint --all "$LINT_FIXTURES/candidate/$base"

        # 候補は違反ではない。終了コード1へ寄与させると、確定判断を doc-reviewer が
        # 担う項目のために書き手が commit 前に書き換える側へ倒れる。
        if [ "$status" -eq 0 ] && output_has_all "$patterns"; then
            collect_ok "$label"
        else
            collect_fail "$label" \
                "expected exit=0 with \"$patterns\", got exit=$status (missing=\"$MISSING_PATTERN\") / output: $output"
        fi
    done

    collect_fixture_coverage candidate "$registered"

    collect_finish
}

@test "面④: 種別プロファイルの一文長の上限が共通規約の既定より優先する" {
    collect_init

    local doc="$LINT_FIXTURES/profile/between-60-and-100.md"
    local profile="$LINT_FIXTURES/profile/type-profiles.md"

    # 既定（汎用・上限100字）では通る。
    run bash "$SUT" --all --profile "$profile" "$doc" </dev/null
    collect_rc 0 "汎用プロファイルでは exit 0"

    # 種別「規約」（上限60字）では一文の長さで落ちる。
    run bash "$SUT" --all --profile "$profile" --type 規約 "$doc" </dev/null
    collect_rc 1 "種別 規約 では exit 1"
    collect_contains "$output" "一文の長さ" "種別 規約 で一文の長さが報告される"

    # 未登録の種別は汎用へフォールバックする。黙って落ちない。
    run bash "$SUT" --all --profile "$profile" --type 存在しない種別 "$doc" </dev/null
    collect_rc 0 "未登録の種別は汎用へフォールバックして exit 0"

    collect_finish
}

@test "面⑤: 上限の列を位置ではなくヘッダのセル名で特定する" {
    collect_init

    # 表へ「備考」の列を1つ足す。上限を最後の列という位置で拾うと、備考に書いた
    # 課題番号が上限として解決され、警告も出ないまま第5条の検査が無効化される。
    local profile="$BATS_TEST_TMPDIR/extra-column.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 | 備考 |\n'
        printf '|---|---|---|---|---|\n'
        printf '| 規約 | 定めない | 一般読者 | 60字 | #684 で追加 |\n'
    } >"$profile"

    local doc="$LINT_FIXTURES/profile/between-60-and-100.md"
    run bash "$SUT" --all --profile "$profile" --type 規約 "$doc" </dev/null
    collect_rc 1 "備考の列があっても上限60字で判定する"
    collect_contains "$output" "上限 60字" "解決された上限が60字である"

    collect_finish
}

@test "面⑥: 種別が引けないとき同梱の既定プロファイルへ連鎖する" {
    collect_init

    # 同梱既定の値が効いていることを観測するには、既定の汎用と共通規約の補則の
    # 既定値が別の数値である必要がある。検査器を複製し、隣に別の値を持つ既定を置く。
    local root="$BATS_TEST_TMPDIR/chain"
    mkdir -p "$root/scripts" "$root/references"
    cp "$SUT" "$root/scripts/lint-ja.sh"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 200字 |\n'
    } >"$root/references/document-type-profiles.md"

    # プロジェクト固有の側は汎用の行を持たない。
    local project="$root/project-profile.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 規約 | 定めない | 一般読者 | 60字 |\n'
    } >"$project"

    local doc="$root/doc.md"
    printf '%s\n' "$(printf 'あ%.0s' $(seq 125))。" >"$doc"

    run bash "$root/scripts/lint-ja.sh" --all --profile "$project" --type 汎用 "$doc" </dev/null
    collect_rc 0 "汎用の行が無ければ同梱既定の200字が効く"

    run bash "$root/scripts/lint-ja.sh" --all --profile "$project" --type 規約 "$doc" </dev/null
    collect_rc 1 "プロジェクト固有に行がある種別はその値を採る"

    collect_finish
}

@test "面⑦: 既定の入力単位が差分であり、ファイル全体の検査は --all でのみ行われる" {
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

@test "面⑧: 変更行を含む文をファイル本体から復元してから判定する" {
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
    # 版に依らない形で書き換える（BSD 版の sed は -i に引数を要求する）。
    sed 's/意味を取れるかどうかを/意味を正しく取れるかどうかを/' "$repo/doc.md" >"$repo/doc.md.new"
    mv "$repo/doc.md.new" "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 1 "ハンクに載らない前後の行を含めて一文として判定する"
    collect_contains "$output" "一文の長さ" "復元後の長さで一文の長さが報告される"

    collect_finish
}

@test "面⑨: 判定の単位は文であり、同じ段落の触れていない文は報告しない" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/sentence-scope"
    init_temp_repo "$repo"

    # 1つの段落に2つの文を置く。1文目は上限を超え、2文目は収まる。
    local long
    long="既存の長い文であり$(printf 'あ%.0s' $(seq 120))。"
    {
        printf '# 文単位の判定\n\n'
        printf '%s\n' "$long"
        printf '同じ段落の二行目である。\n'
    } >"$repo/doc.md"
    commit_all "$repo" "既存の違反を含む段落"

    # 触れるのは2文目だけにする。段落を単位にすると1文目まで赤くなる。
    sed 's/同じ段落の二行目である。/同じ段落の二行目を短く直した。/' "$repo/doc.md" >"$repo/doc.md.new"
    mv "$repo/doc.md.new" "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 0 "同じ段落にある触れていない文の既存の違反は報告しない"

    run_sut_in "$repo" --all doc.md
    collect_rc 1 "--all では同じ違反が報告される（違反自体は残っている）"

    collect_finish
}

@test "面⑩: 未追跡の新規文書と非 ASCII のファイル名を検査する" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/untracked"
    init_temp_repo "$repo"
    printf 'seed\n' >"$repo/seed.txt"
    commit_all "$repo" "起点"

    # 適用範囲の筆頭は新しく起草する文書である。追跡される前が最も検査したい時点で
    # あり、ここで素通りすると「検査していない」と「違反なし」が同じ終了コードになる。
    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/新しい文書.md"

    run_sut_in "$repo"
    collect_rc 1 "未追跡かつ非 ASCII の名前でも検査する"
    collect_contains "$output" "一文の長さ" "未追跡の文書で一文の長さが報告される"

    # 差分の接頭辞を変える設定でも見失わない。
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "追加"
    printf '\n%s\n' "$(cat "$LINT_FIXTURES/invalid/01-sentence-too-long.md" | tail -n 3 | head -n 1)" \
        >>"$repo/新しい文書.md"

    git -C "$repo" config diff.noprefix true
    run_sut_in "$repo"
    collect_rc 1 "diff.noprefix が有効でも検査する"
    git -C "$repo" config --unset diff.noprefix

    git -C "$repo" config diff.mnemonicPrefix true
    run_sut_in "$repo"
    collect_rc 1 "diff.mnemonicPrefix が有効でも検査する"
    git -C "$repo" config --unset diff.mnemonicPrefix

    collect_finish
}

@test "面⑪: 入力が不正なときは exit 2 で止まり、成功を返さない" {
    collect_init

    local doc="$LINT_FIXTURES/valid/01-plain.md"

    run bash "$SUT" --all </dev/null
    collect_rc 2 "--all にパスの指定が無い"

    run bash "$SUT" --all --profile "$BUNDLED_PROFILE" "$BATS_TEST_TMPDIR/no-such.md" </dev/null
    collect_rc 2 "--all に存在しないファイル"

    # Markdown 以外は両方のモードで検査しない。明示的に渡された場合は黙って
    # 飛ばさず、検査していないことが分かる形で止める。
    cp "$doc" "$BATS_TEST_TMPDIR/doc.mdx"
    run bash "$SUT" --all --profile "$BUNDLED_PROFILE" "$BATS_TEST_TMPDIR/doc.mdx" </dev/null
    collect_rc 2 "--all に Markdown 以外のファイル"

    run bash "$SUT" --all --profile "$BATS_TEST_TMPDIR/no-such-profile.md" "$doc" </dev/null
    collect_rc 2 "存在しないプロファイル"

    # 上限が想定の範囲を外れる値は、既定へ黙って落とさずに止める。
    local bad="$BATS_TEST_TMPDIR/bad-profile.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 上限は定めない |\n'
    } >"$bad"
    run bash "$SUT" --all --profile "$bad" "$doc" </dev/null
    collect_rc 2 "上限の欄に数値が無い"

    local huge="$BATS_TEST_TMPDIR/huge-profile.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 99999字 |\n'
    } >"$huge"
    run bash "$SUT" --all --profile "$huge" "$doc" </dev/null
    collect_rc 2 "上限が想定の範囲を外れる"

    # 差分モードでも、一致するものが無いパスは成功を返さない。
    local repo="$BATS_TEST_TMPDIR/missing-path"
    init_temp_repo "$repo"
    printf 'seed\n' >"$repo/seed.txt"
    commit_all "$repo" "起点"
    run_sut_in "$repo" no-such.md
    collect_rc 2 "差分モードに存在しないパス"

    collect_finish
}
