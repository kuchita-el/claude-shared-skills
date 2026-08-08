#!/usr/bin/env bats
# lint-ja.sh の負例 fixture が、本当にその検出条件によって赤くなっているかを確かめる。
#
# 負例が赤いことは、その負例が意図した欠陥を突いている証拠にはならない。別の検出項目が
# たまたま反応しているだけでも赤くなる。検出条件を1つずつ無効化した変異体を作り、対応
# する負例だけが緑へ転じ、他の負例は赤のまま残ることを確かめる。
#
# この検査を置くのは、検査語彙を狭めたときに、その語彙へ依存していた負例が黙って無力化
# する事故を捕まえるためである。負例は赤いままに見えて、実際には何も守っていない状態に
# なりうる。変異が実際に適用されたこと（置換の空振りでないこと）も併せて検査する。
#
# 変異体は一時ディレクトリへ複製したうえで書き換える。被テスト検査器そのものへ無効化の
# 経路を作らない。テスト専用の抜け道を製品側へ残さないためである。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"
ALLOWLIST="$REPO_ROOT/plugins/writing/scripts/allowlist"

CORPORA=()
PRECONDITION_PATHS=(
    "$SUT"
    "$LINT_FIXTURES/invalid"
    "$ALLOWLIST"
)

# 負例の一覧。lint-ja.bats の INVALID_FIXTURES と同じ集合を指す。
NEGATIVES=(
    "01-sentence-too-long.md"
    "02-ungrounded-english.md"
    "03-ungrounded-katakana.md"
    "04-bare-identifier.md"
    "05-identifier-in-inline-code-bare.md"
    "06-sentence-across-lines.md"
    "07-paren-inner-period.md"
)

# <キー>|<変異の説明>|<sed プログラム>|<緑へ転じることを期待する負例（空白区切りの接頭辞）>
MUTATIONS=(
    "length-off|一文の長さの判定を無効化する|s/^check_length() {$/check_length() {\n    return 0/|01 06 07"
    "ungrounded-off|未接地語の語の切り出しを無効化する|s/^scan_ungrounded_tokens() {$/scan_ungrounded_tokens() {\n    return 0/|02 03"
    "identifier-off|不透明な識別子の判定を無効化する|s/^check_identifiers() {$/check_identifiers() {\n    return 0/|04 05"
    "drop-katakana|未接地語の対象からカタカナを落とす|/grep -oE \"\\[\\\$KATAKANA\\]/d|03"
    "drop-english|未接地語の対象から英語を落とす|/grep -oE \"\\[A-Za-z\\]\\[A-Za-z\\]/d|02"
    "keep-backticks|識別子の判定でインラインコードの囲みを外さない|s@^    naked=\"\\\${sentence//.*@    naked=\"\$sentence\"@|05"
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

# 変異体（または原本）へ負例を1件食わせる。許可リストとプロファイルは明示的に渡す。
# 変異体は一時ディレクトリに置かれ、同梱の資源を相対パスで解決できないためである。
run_lint() {
    local script="$1" fixture="$2"
    run bash "$script" --all \
        --allowlist "$ALLOWLIST" \
        --profile "$REPO_ROOT/plugins/writing/references/document-type-profiles.md" \
        "$LINT_FIXTURES/invalid/$fixture" </dev/null
}

@test "前提: 被テスト検査器と負例 fixture が存在する" {
    assert_preconditions_met
}

@test "基準: 変異前はすべての負例が赤い" {
    collect_init

    local fixture
    for fixture in "${NEGATIVES[@]}"; do
        run_lint "$SUT" "$fixture"
        collect_rc 1 "変異前 $fixture が exit 1"
    done

    collect_finish
}

@test "変異: 各検出条件を無効化すると、対応する負例だけが緑へ転じる" {
    collect_init

    local entry key desc program expected mutant fixture prefix want
    for entry in "${MUTATIONS[@]}"; do
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

        for fixture in "${NEGATIVES[@]}"; do
            prefix="${fixture%%-*}"
            want=1
            case " $expected " in
                *" $prefix "*) want=0 ;;
            esac

            run_lint "$mutant" "$fixture"
            if [ "$status" -eq "$want" ]; then
                collect_ok "変異 $key: $fixture が exit $want"
            elif [ "$want" -eq 0 ]; then
                collect_fail "変異 $key: $fixture が exit 0" \
                    "検出条件を無効化しても赤のまま。この負例は当該の条件で赤くなっていない / output: $output"
            else
                collect_fail "変異 $key: $fixture が exit 1" \
                    "無関係なはずの負例まで緑へ転じた。変異の射程が広すぎる / output: $output"
            fi
        done
    done

    collect_finish
}
