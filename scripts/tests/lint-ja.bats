#!/usr/bin/env bats
# 日本語文書の機械検査（plugins/writing/scripts/lint-ja.sh）のテスト。
#
# scripts/fixtures/lint-ja/{valid,invalid,candidate}/*.md を検査し、valid は exit 0 かつ
# 無出力、invalid は exit 1 と期待診断、candidate は exit 0 と候補の出力を検査する。
# 加えて、種別プロファイルの解決・既定の入力単位（差分）・判定の単位（文）・報告する
# 行番号・入力が不正な場合の exit 2 を検査する。
#
# 診断は**標準出力**に出ることを検査する。bats の `run` は既定で標準エラーを標準出力へ
# 併合するため、`$output` だけを見ると出力先を標準エラーへ移す退行が検出できない。
# 検査器の出力を `| grep` や commit 前ゲートへ繋ぐ経路がまとめて壊れるため、
# `run --separate-stderr` で両者を分けて見る。
#
# fixture 名は静的な配列として列挙する。ディレクトリを走査して動的に列挙すると
# 登録ケース数が入力で変動し、報告総数が固定でなくなる（lint-domain-doc.bats と同じ方針）。
#
# 検査対象の fixture は既定の入力単位（差分）ではなく `--all` で回す。差分を既定に
# したまま単体のファイルを渡すと、その fixture が差分に現れないため常に緑になり、
# 判定が素通りする。差分そのものの挙動は一時リポジトリを作る面が検査する。
#
# 種別プロファイルは、それ自体を対象とする面を除いて明示的に渡す。省略すると解決先が
# 作業ディレクトリに従属し、本リポジトリの `.claude/writing/type-profiles.md` を読む面と
# 同梱既定を読む面へ割れる。ただし省略経路そのものにも面を1つ置く。全面で明示すると、
# プロジェクト固有プロファイルの解決という実運用の既定経路が一度も走らなくなる。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"
BUNDLED_PROFILE="$REPO_ROOT/plugins/writing/references/document-type-profiles.md"

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
    "10-exactly-at-limit.md"
    "11-table-and-quote-ignored.md"
    "12-front-matter-ignored.md"
    "13-list-marker-stripped.md"
    "14-emphasis-not-counted.md"
    "15-reference-link-not-counted.md"
    "16-strikethrough-not-counted.md"
    "17-tab-indented-code-ignored.md"
    "18-nested-fence-ignored.md"
    "19-html-comment-ignored.md"
    "20-numbered-list-marker-stripped.md"
    "21-setext-heading-ignored.md"
    "22-borderless-table-ignored.md"
    "23-long-heading-ignored.md"
)

# <ファイル名>|<期待する違反のラベル>|<候補を伴うか（yes/no）>
# 負例は1つの型だけを突く。期待しないラベルの違反が混ざっていれば失敗とする。
# 候補の有無も固定する。負例へ候補が生えても違反ではないため終了コードは動かず、
# 検出語彙を広げて誤検出が増えたことに気づけない。
INVALID_FIXTURES=(
    "01-sentence-too-long.md|一文の長さ|no"
    "02-sentence-across-lines.md|一文の長さ|no"
    "03-paren-inner-period.md|一文の長さ|no"
    "04-issue-number-at-line-start.md|一文の長さ|yes"
    "05a-bracket-kagi.md|一文の長さ|no"
    "05b-bracket-double-kagi.md|一文の長さ|no"
    "05c-bracket-sumi.md|一文の長さ|no"
    "05d-bracket-fullwidth-square.md|一文の長さ|no"
    "05e-bracket-ascii-paren.md|一文の長さ|no"
    "05f-bracket-ascii-square.md|一文の長さ|no"
    "06-halfwidth-marks-not-delimiters.md|一文の長さ|no"
    "07-line-number.md|一文の長さ|no"
    "08-codespan-markup-counted.md|一文の長さ|no"
    "09-unclosed-fence.md|一文の長さ|no"
    "10-unclosed-front-matter.md|一文の長さ|no"
    "11-comment-on-same-line.md|一文の長さ|no"
)

# <ファイル名>|<候補の行に含まれることを期待する文字列>
# 候補は違反ではない。出力は出るが exit 0 で終わる。
CANDIDATE_FIXTURES=(
    "01-bare-identifier.md|ADR-202606040737-01"
    "02-identifier-in-inline-code-bare.md|ADR-202606040737-01"
    "03-issue-number.md|#684"
    "04-particle-ga.md|ADR-202606040737-01"
    "05-particle-wo.md|ADR-202606040737-01"
)

CANDIDATE_LABEL="[候補: 不透明な識別子]"

setup_file() {
    common_setup_file
}

# 種別プロファイルを明示して検査器を起動する。標準出力と標準エラーを分けて受け取る。
lint() {
    run --separate-stderr bash "$SUT" --profile "$BUNDLED_PROFILE" "$@" </dev/null
}

# 出力から候補の行を除いた残り（＝違反の行）を返す。
violation_lines() {
    printf '%s\n' "$1" | grep -v -F "$CANDIDATE_LABEL" | grep -v '^$' || true
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
# 差分まわりの面はこの上で行う。コミット者情報は環境に依存させない。
init_temp_repo() {
    local dir="$1"
    mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email "test@example.invalid"
    git -C "$dir" config user.name "lint-ja test"
    # 署名は利用者の環境設定に依存し、鍵や署名エージェントが無い環境では commit が
    # 落ちる。検査の対象は差分の解釈であって署名ではないため、一時リポジトリでは切る。
    git -C "$dir" config commit.gpgsign false
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

@test "面①: valid fixture がいずれも exit 0 かつ標準出力・標準エラーとも空" {
    collect_init

    local base label
    for base in "${VALID_FIXTURES[@]}"; do
        label="valid/$base (exit=0, 無出力)"
        lint --all "$LINT_FIXTURES/valid/$base"
        if [ "$status" -eq 0 ] && [ -z "$output" ] && [ -z "$stderr" ]; then
            collect_ok "$label"
        else
            # 1件目で打ち切らない。壊れた fixture が複数あれば1回の実行で全件出す。
            collect_fail "$label" \
                "expected exit=0 with no output, got=$status / stdout: $output / stderr: $stderr"
        fi
    done

    collect_fixture_coverage valid "${VALID_FIXTURES[*]}"

    collect_finish
}

@test "面②: invalid fixture が期待する型の違反だけを標準出力へ出して exit 1" {
    collect_init

    local entry base want cand label lines other registered=""
    for entry in "${INVALID_FIXTURES[@]}"; do
        base="${entry%%|*}"
        cand="${entry##*|}"
        want="${entry#*|}"
        want="${want%%|*}"
        registered="$registered $base"

        lint --all "$LINT_FIXTURES/invalid/$base"

        label="invalid/$base (exit=1)"
        if [ "$status" -eq 1 ]; then
            collect_ok "$label"
        else
            collect_fail "$label" "expected exit=1, got=$status / stdout: $output / stderr: $stderr"
        fi

        # 診断は標準出力へ出る。標準エラーへ移す退行をここで捕まえる。
        label="invalid/$base (診断が標準出力に出る)"
        if [[ "$output" == *"[$want]"* ]]; then
            collect_ok "$label"
        else
            collect_fail "$label" "標準出力に [$want] が無い / stdout: $output / stderr: $stderr"
        fi

        # 負例は1つの型だけを突く。別の型の違反が混ざっていれば、その負例は意図した
        # 条件で赤くなっているとは限らない。
        label="invalid/$base (期待しない型の違反が出ていない)"
        lines="$(violation_lines "$output")"
        other="$(printf '%s\n' "$lines" | grep -v -F "[$want]" | grep -v '^$' || true)"
        if [ -z "$other" ]; then
            collect_ok "$label"
        else
            collect_fail "$label" "期待しない違反が出ている: $other"
        fi

        label="invalid/$base (候補の有無が $cand)"
        if [[ "$output" == *"$CANDIDATE_LABEL"* ]]; then
            [ "$cand" = "yes" ] && collect_ok "$label" ||
                collect_fail "$label" "候補を伴わない負例に候補が生えている / stdout: $output"
        else
            [ "$cand" = "no" ] && collect_ok "$label" ||
                collect_fail "$label" "候補を伴うはずの負例に候補が無い / stdout: $output"
        fi
    done

    collect_fixture_coverage invalid "$registered"

    collect_finish
}

@test "面③: candidate fixture が候補を標準出力へ出しつつ exit 0" {
    collect_init

    local entry base want label registered=""
    for entry in "${CANDIDATE_FIXTURES[@]}"; do
        base="${entry%%|*}"
        want="${entry#*|}"
        registered="$registered $base"

        lint --all "$LINT_FIXTURES/candidate/$base"

        # 候補は違反ではない。終了コード1へ寄与させると、確定判断を doc-reviewer が
        # 担う項目のために書き手が commit 前に書き換える側へ倒れる。
        label="candidate/$base (exit=0)"
        collect_rc 0 "$label"

        label="candidate/$base (候補が標準出力に出る)"
        if [[ "$output" == *"$CANDIDATE_LABEL"* ]] && [[ "$output" == *"$want"* ]]; then
            collect_ok "$label"
        else
            collect_fail "$label" "標準出力に候補が無い / stdout: $output / stderr: $stderr"
        fi
    done

    collect_fixture_coverage candidate "$registered"

    collect_finish
}

@test "面④: 報告する行番号が、段落を連結した後も元の行を指す" {
    collect_init

    # 07-line-number.md は見出し・箇条書き・短い段落を挟んだうえで、7行目から
    # 始まる3行の段落に違反を置いてある。段落内オフセットから行番号を逆引きする
    # 処理を通らないと、この値は出ない。
    lint --all "$LINT_FIXTURES/invalid/07-line-number.md"
    collect_rc 1 "行番号の fixture が exit 1"
    collect_contains "$output" "07-line-number.md:7:" "違反が7行目として報告される"
    collect_not_contains "$output" "07-line-number.md:1:" "見出しの行番号で報告されない"
    collect_not_contains "$output" "07-line-number.md:9:" "段落の最終行で報告されない"

    collect_finish
}

@test "面⑤: 注釈は行ではなく文字の範囲で落とす" {
    collect_init

    # 行単位で落とすと、注釈と同じ行に置いた地の文が黙って未検査になり、行の途中で
    # 閉じた注釈より後ろが過大に数えられる。両方向を見る。変異では両者を1つの置換で
    # 分けられないため、振る舞いを直接おさえる。
    local dir="$BATS_TEST_TMPDIR/comment-range"
    mkdir -p "$dir"
    local long
    long="$(printf 'あ%.0s' $(seq 130))。"

    printf '<!-- 注釈 -->%s\n' "$long" >"$dir/after.md"
    lint --all "$dir/after.md"
    collect_rc 1 "注釈と同じ行に置いた地の文を検査する"
    collect_contains "$output" "一文の長さ" "地の文の長さが報告される"

    printf '%s<!-- 行の途中に置いた注釈 -->。\n' "$(printf 'あ%.0s' $(seq 95))" >"$dir/inline.md"
    lint --all "$dir/inline.md"
    collect_rc 0 "行の途中の注釈は字数に数えない"

    printf '<!-- 閉じない注釈\n%s\n' "$long" >"$dir/unclosed.md"
    lint --all "$dir/unclosed.md"
    collect_rc 1 "閉じない注釈は範囲を作らない"

    collect_finish
}

@test "面⑥: 種別プロファイルの一文長の上限が共通規約の既定より優先する" {
    collect_init

    local doc="$LINT_FIXTURES/profile/between-60-and-100.md"
    local profile="$LINT_FIXTURES/profile/type-profiles.md"

    run bash "$SUT" --all --profile "$profile" "$doc" </dev/null
    collect_rc 0 "汎用プロファイルでは exit 0"

    run bash "$SUT" --all --profile "$profile" --type 規約 "$doc" </dev/null
    collect_rc 1 "種別 規約 では exit 1"
    collect_contains "$output" "一文の長さ" "種別 規約 で一文の長さが報告される"

    run bash "$SUT" --all --profile "$profile" --type 存在しない種別 "$doc" </dev/null
    collect_rc 0 "未登録の種別は汎用へフォールバックして exit 0"

    collect_finish
}

@test "面⑦: 上限の列を位置ではなくヘッダのセル名で特定する" {
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

@test "面⑧: 種別が引けないとき同梱の既定プロファイルへ連鎖する" {
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

@test "面⑨: --profile を省略するとプロジェクト固有のプロファイルを解決する" {
    collect_init

    # 実運用の既定経路である。全面で --profile を明示すると、この解決が一度も走らない。
    # 解決の基点は作業ディレクトリではなくリポジトリのルートであることも併せて見る。
    local repo="$BATS_TEST_TMPDIR/implicit-profile"
    init_temp_repo "$repo"
    mkdir -p "$repo/.claude/writing" "$repo/sub"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 60字 |\n'
    } >"$repo/.claude/writing/type-profiles.md"
    printf '%s\n' "$(printf 'あ%.0s' $(seq 61))。" >"$repo/doc.md"

    pushd "$repo" >/dev/null || return 1
    run env -u CLAUDE_PROJECT_DIR bash "$SUT" --all doc.md </dev/null
    popd >/dev/null || return 1
    collect_rc 1 "ルートから: プロジェクト固有の60字が効く"
    collect_contains "$output" "上限 60字" "ルートから: 解決された上限が60字である"

    pushd "$repo/sub" >/dev/null || return 1
    run env -u CLAUDE_PROJECT_DIR bash "$SUT" --all ../doc.md </dev/null
    popd >/dev/null || return 1
    collect_rc 1 "サブディレクトリから: 同じ上限が効く"
    collect_contains "$output" "上限 60字" "サブディレクトリから: 解決された上限が60字である"

    collect_finish
}

@test "面⑩: 既定の入力単位が差分であり、ファイル全体の検査は --all でのみ行われる" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/diff-default"
    init_temp_repo "$repo"

    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/doc.md"
    commit_all "$repo" "既存の違反を含む文書"

    printf '\n新しく足した段落はいずれの検出項目にも当たらない。\n' >>"$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 0 "差分が既定: 触れていない既存の違反は報告しない"

    run_sut_in "$repo" --all doc.md
    collect_rc 1 "--all: ファイル全体の既存の違反を報告する"
    collect_contains "$output" "一文の長さ" "--all で一文の長さが報告される"

    # 対照。同じ差分モードで、触れた行に違反があれば報告される。これが無いと、
    # 列挙が丸ごと死んでいても上の「報告しない」が緑のまま通る。
    printf '\n%s\n' "$(sed -n '3p' "$LINT_FIXTURES/invalid/01-sentence-too-long.md")" >>"$repo/doc.md"
    run_sut_in "$repo" doc.md
    collect_rc 1 "対照: 触れた行に違反があれば差分モードでも報告する"

    collect_finish
}

@test "面⑪: 変更行を含む文をファイル本体から復元してから判定する" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/restore"
    init_temp_repo "$repo"

    {
        printf '# 復元の検査\n\n'
        printf '検査の対象となる文書は、書き手が書いた内容をそのまま保つ形で保存されており、\n'
        printf '読み手が最初から最後まで順に読み進めたときに意味を取れるかどうかを\n'
        printf '確かめる必要があるため、ここでは一文を三つの行へ分けて書いてある。\n'
    } >"$repo/doc.md"
    commit_all "$repo" "複数行にまたがる一文"

    # 版に依らない形で書き換える（BSD 版の sed は -i に引数を要求する）。
    sed 's/意味を取れるかどうかを/意味を正しく取れるかどうかを/' "$repo/doc.md" >"$repo/doc.md.new"
    mv "$repo/doc.md.new" "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 1 "ハンクに載らない前後の行を含めて一文として判定する"
    collect_contains "$output" "一文の長さ" "復元後の長さで一文の長さが報告される"

    collect_finish
}

@test "面⑫: 判定の単位は文であり、触れていない文は報告しない" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/sentence-scope"
    init_temp_repo "$repo"

    local long
    long="既存の長い文であり$(printf 'あ%.0s' $(seq 120))。"
    {
        printf '# 文単位の判定\n\n'
        printf '%s\n' "$long"
        printf '同じ段落の二行目である。\n'
        printf '\n消される行。\n'
    } >"$repo/doc.md"
    commit_all "$repo" "既存の違反を含む段落"

    # 同じ段落の別の文だけを触る。段落を単位にすると1文目まで赤くなる。
    sed 's/同じ段落の二行目である。/同じ段落の二行目を短く直した。/' "$repo/doc.md" >"$repo/doc.md.new"
    mv "$repo/doc.md.new" "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 0 "同じ段落にある触れていない文の既存の違反は報告しない"

    # 追加行がゼロの差分（純削除）。空集合を「絞らない」と取り違えると全行検査へ落ちる。
    git -C "$repo" checkout -q -- doc.md
    sed '/^消される行。$/d' "$repo/doc.md" >"$repo/doc.md.new"
    mv "$repo/doc.md.new" "$repo/doc.md"

    run_sut_in "$repo" doc.md
    collect_rc 0 "純削除だけの差分では触れていない文を報告しない"

    run_sut_in "$repo" --all doc.md
    collect_rc 1 "--all では同じ違反が報告される（違反自体は残っている）"

    # 対照。純削除の差分へ1行足せば報告される。列挙が死んでいないことを示す。
    printf '\n%s\n' "$long" >>"$repo/doc.md"
    run_sut_in "$repo" doc.md
    collect_rc 1 "対照: 削除に加えて違反を1行足せば報告する"

    collect_finish
}

@test "面⑬: 未追跡の新規文書と非 ASCII のファイル名を検査する" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/untracked"
    init_temp_repo "$repo"
    mkdir -p "$repo/sub"
    printf 'seed\n' >"$repo/seed.txt"
    commit_all "$repo" "起点"

    # 適用範囲の筆頭は新しく起草する文書である。追跡される前が最も検査したい時点で
    # あり、ここで素通りすると「検査していない」と「違反なし」が同じ終了コードになる。
    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/新しい文書.md"

    run_sut_in "$repo"
    collect_rc 1 "未追跡かつ非 ASCII の名前でも検査する"
    collect_contains "$output" "一文の長さ" "未追跡の文書で一文の長さが報告される"

    # 列挙の射程はリポジトリ全体である。作業ディレクトリ配下に限ると、
    # サブディレクトリから起動しただけでルートの未追跡文書が落ちる。
    run_sut_in "$repo/sub"
    collect_rc 1 "サブディレクトリから起動してもルートの未追跡文書を拾う"

    git -C "$repo" add -A
    git -C "$repo" commit -q -m "追加"
    printf '\n%s\n' "$(sed -n '3p' "$LINT_FIXTURES/invalid/01-sentence-too-long.md")" \
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

@test "面⑭: --base は分岐点を採り、--two-dot でのみ2点間差分になる" {
    collect_init

    local repo="$BATS_TEST_TMPDIR/merge-base"
    init_temp_repo "$repo"
    # 分岐する前から存在し、違反を含むファイル。作業ブランチはこれに触れない。
    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/other.md"
    commit_all "$repo" "起点"

    git -C "$repo" checkout -q -b topic
    printf '# 作業\n\n短い文である。\n' >"$repo/topic.md"
    commit_all "$repo" "作業ブランチの変更"

    # 分岐した後に基点のブランチだけが other.md を書き換える。作業ブランチの木は
    # 分岐時点のままなので、2点間差分では触れていない行が「追加」として現れる。
    git -C "$repo" checkout -q main
    printf '# 短い文書\n\n短い文である。\n' >"$repo/other.md"
    commit_all "$repo" "基点のブランチが進む"
    git -C "$repo" checkout -q topic

    run_sut_in "$repo" --base main
    collect_rc 0 "分岐点を採るため、触れていない other.md は報告しない"

    run_sut_in "$repo" --two-dot --base main
    collect_rc 1 "--two-dot では2点間差分になり other.md が報告される"
    collect_contains "$output" "other.md" "2点間差分では other.md が対象になる"

    # 対照。この作業ブランチが実際に触れた違反は、分岐点を採っても報告される。
    cp "$LINT_FIXTURES/invalid/01-sentence-too-long.md" "$repo/topic.md"
    run_sut_in "$repo" --base main
    collect_rc 1 "対照: 作業ブランチが触れた違反は分岐点を採っても報告する"

    collect_finish
}

@test "面⑮: 入力が不正なときは exit 2 で止まり、成功を返さない" {
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
    collect_rc 2 "上限が想定の範囲を外れる（上振れ）"

    local tiny="$BATS_TEST_TMPDIR/tiny-profile.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文長の上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 5字 |\n'
    } >"$tiny"
    run bash "$SUT" --all --profile "$tiny" "$doc" </dev/null
    collect_rc 2 "上限が想定の範囲を外れる（下振れ）"

    # 列名がずれると指定が黙って捨てられ、既定へ緩む。名前の一致まで見る。
    local renamed="$BATS_TEST_TMPDIR/renamed-column.md"
    {
        printf '| 種別 | 節構成 | 読み手の既定 | 一文の長さの上限 |\n'
        printf '|---|---|---|---|\n'
        printf '| 汎用 | 定めない | 一般読者 | 60字 |\n'
    } >"$renamed"
    run bash "$SUT" --all --profile "$renamed" "$doc" </dev/null
    collect_rc 2 "上限の列名がずれている"

    # 読めない資源は、最も強い解決の失敗である。既定へ緩めず止める。
    local unreadable="$BATS_TEST_TMPDIR/unreadable-profile.md"
    cp "$BUNDLED_PROFILE" "$unreadable"
    chmod 000 "$unreadable"
    if [ -r "$unreadable" ]; then
        # root 実行や権限の効かないファイルシステムでは成立しない。
        collect_skipped "読めないプロファイル" "chmod が効かない実行環境"
    else
        run bash "$SUT" --all --profile "$unreadable" "$doc" </dev/null
        collect_rc 2 "読めないプロファイル"
    fi
    chmod 644 "$unreadable"

    local unreadable_doc="$BATS_TEST_TMPDIR/unreadable.md"
    cp "$doc" "$unreadable_doc"
    chmod 000 "$unreadable_doc"
    if [ -r "$unreadable_doc" ]; then
        collect_skipped "読めない検査対象" "chmod が効かない実行環境"
    else
        run bash "$SUT" --all --profile "$BUNDLED_PROFILE" "$unreadable_doc" </dev/null
        collect_rc 2 "読めない検査対象"
    fi
    chmod 644 "$unreadable_doc"

    # 差分モードでも、一致するものが無いパスと Markdown 以外は成功を返さない。
    local repo="$BATS_TEST_TMPDIR/bad-input"
    init_temp_repo "$repo"
    printf 'seed\n' >"$repo/seed.txt"
    commit_all "$repo" "起点"
    run_sut_in "$repo" no-such.md
    collect_rc 2 "差分モードに存在しないパス"

    cp "$doc" "$repo/doc.mdx"
    run_sut_in "$repo" doc.mdx
    collect_rc 2 "差分モードに Markdown 以外のファイル"

    # commit 以外のオブジェクトを基点に渡すと、後段の git diff が使い方の誤りで落ちる。
    # その失敗を握り潰すと全件0になる。
    run_sut_in "$repo" --base "HEAD:seed.txt"
    collect_rc 2 "commit ではないオブジェクトを基点に指定"

    collect_finish
}
