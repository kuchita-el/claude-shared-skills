#!/usr/bin/env bats
# lint-ja.sh の fixture が、本当にその条件によって赤く（あるいは緑に）なっているかを確かめる。
#
# 負例が赤いことは、その負例が意図した欠陥を突いている証拠にはならない。別の検出項目が
# たまたま反応しているだけでも赤くなる。同じことが正例にも成り立つ。正例が緑なのは免除や
# 除外が効いたからとは限らず、そもそも検出条件に触れていないだけでも緑になる。
#
# そこで変異を2つの向きへ置く。
#
#   検出殺し   検出条件を無効化すると、対応する負例だけが緑へ転じる
#   免除殺し   免除・除外の条件を無効化すると、対応する正例だけが赤へ転じる
#
# 検出殺しだけを置くと、免除と除外の分岐は無検査のまま残る。到達しない死に分岐や、
# 条文が認める形を通していない免除が、正例を緑にしたまま潜り込む。
#
# 候補（第2条）は終了コードに寄与しないため、判定は出力に候補が現れるかで行う。
# 終了コードで判定すると、候補の検出を丸ごと落としても全件緑のまま通る。
#
# 変異が実際に適用されたこと（置換の空振りでないこと）も併せて検査する。
# 変異体は一時ディレクトリへ複製したうえで書き換える。被テスト検査器そのものへ無効化の
# 経路を作らない。テスト専用の抜け道を製品側へ残さないためである。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"
BUNDLED_PROFILE="$REPO_ROOT/plugins/writing/references/document-type-profiles.md"

CORPORA=()
PRECONDITION_PATHS=(
    "$SUT"
    "$LINT_FIXTURES/valid"
    "$LINT_FIXTURES/invalid"
    "$LINT_FIXTURES/candidate"
    "$BUNDLED_PROFILE"
)

# 各群の fixture 一覧。lint-ja.bats の配列と同じ集合を指す。
NEGATIVES=(
    "01-sentence-too-long.md"
    "02-sentence-across-lines.md"
    "03-paren-inner-period.md"
    "04-issue-number-at-line-start.md"
)

POSITIVES=(
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

CANDIDATES=(
    "01-bare-identifier.md"
    "02-identifier-in-inline-code-bare.md"
    "03-issue-number.md"
)

# 書式は <キー>|<変異の説明>|<sed プログラム>|<転じることを期待する fixture の接頭辞>。
# sed プログラムに縦棒を書かない（この配列の区切りと衝突するため）。置換の区切りは @ を使う。

# 検出条件を無効化する。対応する負例だけが exit 1 から exit 0 へ転じる。
MUTATIONS_DETECT=(
    "length-off|一文の長さの判定を無効化する|s/^check_length() {$/check_length() {\n    return 0/|01 02 03 04"
    "heading-loose|見出しの判定を記号だけに戻す|s@^HEADING_RE=.*@HEADING_RE='^#'@|04"
    "paren-depth-off|括弧の対応の数え上げを無効化する|s@^        depth=\$((depth.*@        depth=0@|03"
    "line-join-off|段落の行の連結を無効化する|s@^        buf_last=\"\$lineno\"@        buf_last=\"\$lineno\"\n        flush@|02"
)

# 免除・除外の条件を無効化する。対応する正例だけが exit 0 から exit 1 へ転じる。
MUTATIONS_EXEMPT=(
    "link-strip-off|リンク記法の除去を無効化する|s@^LINK_RE=.*@LINK_RE='NEVER_MATCH_SENTINEL'@|05"
    "delim-only-period|文の区切りから疑問符と感嘆符を落とす|s@^SENT_DELIMS=.*@SENT_DELIMS=('。')@|08"
    "codespan-mask-off|インラインコードの伏せ字を無効化する|s@^    MASKED=\"\$out\$t\"@    MASKED=\"\$1\"@|09"
    "indent-code-off|4字下げのコードブロックの除外を無効化する|s@== '    '\\*@== 'NEVER_MATCH_SENTINEL'*@|07"
    "tilde-fence-off|チルダのフェンスの認識を落とす|s@'~~~'@'NEVER_MATCH_SENTINEL'@|06"
    "backtick-fence-off|バッククォートのフェンスの認識を落とす|s@'\`\`\`'@'NEVER_MATCH_SENTINEL'@|02"
)

# 候補の検出条件を無効化する。対応する候補 fixture だけが候補を出さなくなる。
MUTATIONS_CANDIDATE=(
    "identifier-off|不透明な識別子の判定を無効化する|s/^check_identifiers() {$/check_identifiers() {\n    return 0/|01 02 03"
    "identifier-drop-issue|識別子の形から課題番号を落とす|s@^ID_RE=.*@ID_RE='(ADR-[0-9]{8,12}-[0-9]+)'@|03"
    "identifier-keep-backticks|識別子の判定でインラインコードの囲みを外さない|s@^    naked=.*@    naked=\"\$sentence\"@|02"
)

setup_file() {
    common_setup_file
}

# 変異体を作る。置換が空振りした場合は呼び出し側が検出できるよう、元との差を返す。
build_mutant() {
    local program="$1" out="$2"
    sed "$program" "$SUT" >"$out"
    ! cmp -s "$SUT" "$out"
}

# 変異体（または原本）へ fixture を1件食わせる。種別プロファイルは明示的に渡す。
# 変異体は一時ディレクトリに置かれ、同梱の資源を相対パスで解決できないためである。
run_lint() {
    local script="$1" subdir="$2" fixture="$3"
    run bash "$script" --all \
        --profile "$BUNDLED_PROFILE" \
        "$LINT_FIXTURES/$subdir/$fixture" </dev/null
}

# 1つの変異表を回す。judge は "rc" なら終了コード、"candidate" なら候補の出力で判定する。
# baseline は変異前の期待値、mutated は転じた先の期待値である。
run_mutation_table() {
    local -n table="$1"
    local subdir="$2" judge="$3" baseline="$4" mutated="$5"
    local -n fixtures="$6"

    local entry key desc program expected mutant fixture prefix want actual
    for entry in "${table[@]}"; do
        key="${entry%%|*}"
        entry="${entry#*|}"
        desc="${entry%%|*}"
        entry="${entry#*|}"
        program="${entry%|*}"
        expected="${entry##*|}"

        mutant="$BATS_TEST_TMPDIR/lint-ja-$key.sh"
        if build_mutant "$program" "$mutant"; then
            collect_ok "変異 $key が適用された（$desc）"
        else
            # 置換が空振りしていれば以降の判定は無意味になる。ここで止めずに記録し、
            # 全ての変異について空振りの有無を1回の実行で出す。
            collect_fail "変異 $key が適用された（$desc）" \
                "sed が原本を書き換えていない。変異の対象が改名または移動した可能性がある"
            continue
        fi

        for fixture in "${fixtures[@]}"; do
            prefix="${fixture%%-*}"
            want="$baseline"
            case " $expected " in
                *" $prefix "*) want="$mutated" ;;
            esac

            run_lint "$mutant" "$subdir" "$fixture"
            if [ "$judge" = "rc" ]; then
                actual="$status"
            elif [[ "$output" == *"[候補: "* ]]; then
                actual="あり"
            else
                actual="なし"
            fi

            if [ "$actual" = "$want" ]; then
                collect_ok "変異 $key: $subdir/$fixture が $want"
            elif [ "$want" = "$mutated" ]; then
                collect_fail "変異 $key: $subdir/$fixture が $want" \
                    "条件を無効化しても転じない。この fixture は当該の条件で判定されていない / output: $output"
            else
                collect_fail "変異 $key: $subdir/$fixture が $want" \
                    "無関係なはずの fixture まで転じた。変異の射程が広すぎる / output: $output"
            fi
        done
    done
    return 0
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

@test "基準: 変異前は負例が赤く、正例が緑で、候補は候補を出す" {
    collect_init

    local fixture
    for fixture in "${NEGATIVES[@]}"; do
        run_lint "$SUT" invalid "$fixture"
        collect_rc 1 "変異前 invalid/$fixture が exit 1"
    done
    for fixture in "${POSITIVES[@]}"; do
        run_lint "$SUT" valid "$fixture"
        collect_rc 0 "変異前 valid/$fixture が exit 0"
    done
    for fixture in "${CANDIDATES[@]}"; do
        run_lint "$SUT" candidate "$fixture"
        collect_rc 0 "変異前 candidate/$fixture が exit 0"
        collect_contains "$output" "[候補: " "変異前 candidate/$fixture が候補を出す"
    done

    collect_finish
}

@test "変異: 検出条件を無効化すると、対応する負例だけが緑へ転じる" {
    collect_init
    run_mutation_table MUTATIONS_DETECT invalid rc 1 0 NEGATIVES
    collect_finish
}

@test "変異: 免除と除外を無効化すると、対応する正例だけが赤へ転じる" {
    collect_init
    run_mutation_table MUTATIONS_EXEMPT valid rc 0 1 POSITIVES
    collect_finish
}

@test "変異: 候補の検出条件を無効化すると、対応する候補だけが出なくなる" {
    collect_init
    run_mutation_table MUTATIONS_CANDIDATE candidate candidate あり なし CANDIDATES
    collect_finish
}
