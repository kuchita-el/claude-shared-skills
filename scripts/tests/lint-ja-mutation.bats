#!/usr/bin/env bats
# lint-ja.sh の fixture が、本当にその条件によって赤く（あるいは緑に）なっているかを確かめる。
#
# 負例が赤いことは、その負例が意図した欠陥を突いている証拠にはならない。別の検出項目が
# たまたま反応しているだけでも赤くなる。同じことが正例にも成り立つ。正例が緑なのは免除や
# 除外が効いたからとは限らず、そもそも検出条件に触れていないだけでも緑になる。
#
# そこで変異を3つの向きへ置く。
#
#   検出殺し   検出条件を無効化すると、対応する負例だけが緑へ転じる
#   免除殺し   免除・除外の条件を無効化すると、対応する正例だけが赤へ転じる
#   候補殺し   候補の検出条件を無効化すると、対応する候補だけが出なくなる
#
# 検出殺しだけを置くと、免除と除外の分岐は無検査のまま残る。到達しない死に分岐や、
# 条文が認める形を通していない免除が、正例を緑にしたまま潜り込む。
#
# 候補（第2条）は終了コードに寄与しないため、判定は出力に候補が現れるかでも行う。
# 終了コードだけで判定すると、候補の検出を丸ごと落としても全件緑のまま通る。判定は
# 群を問わず2つの軸（終了コードと候補の有無）の両方で行う。群ごとに片方の軸しか見ないと、
# 終了コードを動かさずに候補だけを消す変異が素通りする。
#
# 変異前の値は宣言せず、原本を走らせて測る。宣言で持つと、宣言と実測がずれても
# 気づけない。
#
# 変異表そのものの縮退も検査する。表が空でも、行が減っても、群や軸が減っても、判定が
# 減るだけで全件緑のまま通るためである。表の項目の有無・判定数の積・文書側の表との
# 1対1をそれぞれ検査項目として持つ。
#
# 変異が実際に適用されたこと（置換の空振りでないこと）も併せて検査する。
# 変異体は一時ディレクトリへ複製したうえで書き換える。被テスト検査器そのものへ無効化の
# 経路を作らない。テスト専用の抜け道を製品側へ残さないためである。

load 'helpers/common'

SUT="$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
LINT_FIXTURES="$REPO_ROOT/scripts/fixtures/lint-ja"
BUNDLED_PROFILE="$REPO_ROOT/plugins/writing/references/document-type-profiles.md"
MUTATION_DOC="$REPO_ROOT/docs/development/test-execution.md"

CORPORA=()
PRECONDITION_PATHS=(
    "$MUTATION_DOC"
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
    "05a-bracket-kagi.md"
    "05b-bracket-double-kagi.md"
    "05c-bracket-sumi.md"
    "05d-bracket-fullwidth-square.md"
    "05e-bracket-ascii-paren.md"
    "05f-bracket-ascii-square.md"
    "06-halfwidth-marks-not-delimiters.md"
    "07-line-number.md"
    "08-codespan-markup-counted.md"
    "09-unclosed-fence.md"
    "10-unclosed-front-matter.md"
    "11-comment-on-same-line.md"
    "12-list-before-thematic-break.md"
    "13-comment-close-in-codespan.md"
    "14-comment-open-in-table-cell.md"
    "15-comment-open-in-quote.md"
    "16-comment-open-in-heading.md"
    "17-comment-open-in-indented-code.md"
    "18-comment-open-in-double-backticks.md"
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
    "24-comment-closed-by-codespan-mark.md"
    "25-list-then-thematic-break.md"
)

CANDIDATES=(
    "01-bare-identifier.md"
    "02-identifier-in-inline-code-bare.md"
    "03-issue-number.md"
    "04-particle-ga.md"
    "05-particle-wo.md"
)

# 書式は <キー>::<変異の説明>::<sed プログラム>::<転じることを期待する fixture の接頭辞>。
# 区切りを2文字にしてあるのは、sed プログラムが縦棒やコロンを1文字だけ含みうるためである。
# 置換の区切りは @ を使う。シェル変数を含む要素は単引用符で括り、退避を保つ。

# 検出条件を無効化する。対応する負例だけが exit 1 から exit 0 へ転じる。
MUTATIONS_DETECT=(
    'length-off::一文の長さの判定を無効化する::s/^check_length() {$/check_length() {\n    return 0/::invalid:01 invalid:02 invalid:03 invalid:04 invalid:05a invalid:05b invalid:05c invalid:05d invalid:05e invalid:05f invalid:06 invalid:07 invalid:08 invalid:09 invalid:10 invalid:11 invalid:12 invalid:13 invalid:14 invalid:15 invalid:16 invalid:17 invalid:18'
    "heading-loose::見出しの判定を記号だけに戻す::s@^HEADING_RE=.*@HEADING_RE='^#'@::invalid:04 invalid:04:候補"
    'paren-depth-off::括弧の対応の数え上げを無効化する::s@^        depth=\$((depth.*@        depth=0@::invalid:03 invalid:05a invalid:05b invalid:05c invalid:05d invalid:05e invalid:05f'
    'line-join-off::段落の行の連結を無効化する::s@^        buf_last="\$lineno"@        buf_last="\$lineno"\n        flush@::invalid:02 invalid:07 valid:21'
    "bracket-drop-kagi::括弧の対から「」を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '『' '【' '［' '(' '[')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '』' '】' '］' ')' ']')@::invalid:05a"
    "bracket-drop-double-kagi::括弧の対から『』を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '「' '【' '［' '(' '[')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '」' '】' '］' ')' ']')@::invalid:05b"
    "bracket-drop-sumi::括弧の対から【】を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '「' '『' '［' '(' '[')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '」' '』' '］' ')' ']')@::invalid:05c"
    "bracket-drop-fullwidth-square::括弧の対から［］を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '「' '『' '【' '(' '[')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '」' '』' '】' ')' ']')@::invalid:05d"
    "bracket-drop-ascii-paren::括弧の対から()を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '「' '『' '【' '［' '[')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '」' '』' '】' '］' ']')@::invalid:05e"
    "bracket-drop-ascii-square::括弧の対から[]を落とす::s@^OPEN_BRACKETS=.*@OPEN_BRACKETS=('（' '「' '『' '【' '［' '(')@; s@^CLOSE_BRACKETS=.*@CLOSE_BRACKETS=('）' '」' '』' '】' '］' ')')@::invalid:05f"
    "halfwidth-delims::半角の疑問符と感嘆符を区切りに加える::s@^SENT_DELIMS=.*@SENT_DELIMS=('。' '？' '！' '?' '!')@::invalid:06"
    'codespan-markup-strip::インラインコードの内側からも記法の記号を落とす::s/^display_text() {$/display_text() {\n    strip_markup "\$1"\n    DISPLAY="\$STRIPPED"\n    return 0/::invalid:08'
    'fence-unclosed-toggle::閉じない囲みでも範囲を作る::s@^            if \[ "\$close" -ge 0 \]; then@            [ "\$close" -ge 0 ] || close=\$((n - 1))\n            if [ "\$close" -ge 0 ]; then@::invalid:09'
    'setext-swallows-list::箇条書きの項目も下線形式の見出しの対象にする::s@\[ "\$buf_is_list" -eq 0 \] && @@::invalid:12'
    'front-matter-unclosed-toggle::閉じない区切り線でも範囲を作る::s@^            if \[ "\$TRIMMED" = "\$FRONT_MATTER_MARK" \]; then@            if [ "\$TRIMMED" = "\$FRONT_MATTER_MARK" ] || [ "\$j" -eq \$((n - 1)) ]; then@::invalid:10'
    'comment-end-masked::注釈の終了を伏せた写しで探す::s@^        tail="\${rest:i+4}"@        tail="\${mrest:i+4}"@::invalid:13 valid:24'
    'codespan-run-pairing-off::コードスパンの囲みの長さの一致を1字に固定する::s@-eq "${#open}"@-eq 1@::invalid:18'
)

# 免除・除外の条件を無効化する。対応する正例だけが exit 0 から exit 1 へ転じる。
MUTATIONS_EXEMPT=(
    "link-strip-off::リンク記法の除去を無効化する::s@^LINK_RE=.*@LINK_RE='NEVER_MATCH_SENTINEL'@::valid:05"
    "reflink-strip-off::参照形式リンクの除去を無効化する::s@^REFLINK_RE=.*@REFLINK_RE='NEVER_MATCH_SENTINEL'@::valid:15"
    "delim-only-period::文の区切りから疑問符と感嘆符を落とす::s@^SENT_DELIMS=.*@SENT_DELIMS=('。')@::valid:08"
    "delim-drop-question::文の区切りから疑問符だけを落とす::s@^SENT_DELIMS=.*@SENT_DELIMS=('。' '！')@::valid:08"
    "delim-drop-exclamation::文の区切りから感嘆符だけを落とす::s@^SENT_DELIMS=.*@SENT_DELIMS=('。' '？')@::valid:08"
    'codespan-mask-off::インラインコードの伏せ字を無効化する::s/^mask_codespans() {$/mask_codespans() {\n    MASKED="\$1"\n    return 0/::valid:09 invalid:18'
    "indent-code-off::半角4字の字下げの除外を無効化する::s@== '    '\\*@== 'NEVER_MATCH_SENTINEL'*@::valid:07 invalid:17"
    "tab-indent-off::タブ1字の字下げの除外を無効化する::s@== \\\$'\\\\t'@== 'NEVER_MATCH_SENTINEL'@::valid:17"
    "tilde-fence-off::チルダのフェンスの認識を落とす::s@'~~~'@'NEVER_MATCH_SENTINEL'@::valid:06"
    "backtick-fence-off::バッククォートのフェンスの認識を落とす::s@'\`\`\`'@'NEVER_MATCH_SENTINEL'@::valid:02"
    "fence-type-mismatch::囲みを別の種類の記号で閉じられるようにする::s@marker='~~~'@marker='\`\`\`'@::valid:06 valid:18"
    "comment-off::注釈の除外を無効化する::s@\\*'<!--'\\*@*'NEVER_MATCH_SENTINEL'*@::valid:19 valid:24"
    "table-row-off::縦棒で始まる表の行の除外を無効化する::s@^TABLE_ROW_RE=.*@TABLE_ROW_RE='NEVER_MATCH_SENTINEL'@::valid:11 invalid:14"
    "borderless-table-off::縦棒で始まらない表の除外を無効化する::s@^    local gfm_sep=.*@    local gfm_sep='NEVER_MATCH_SENTINEL'@::valid:22"
    "quote-row-off::引用の行の除外を無効化する::s@^QUOTE_ROW_RE=.*@QUOTE_ROW_RE='NEVER_MATCH_SENTINEL'@::valid:11 invalid:15"
    "heading-off::見出しの行の除外を無効化する::s@^HEADING_RE=.*@HEADING_RE='NEVER_MATCH_SENTINEL'@::valid:23 invalid:16"
    "setext-off::下線形式の見出しの除外を無効化する::s@^SETEXT_RE=.*@SETEXT_RE='NEVER_MATCH_SENTINEL'@::valid:21 valid:25"
    "front-matter-off::冒頭のメタデータの除外を無効化する::s@^FRONT_MATTER_MARK=.*@FRONT_MATTER_MARK='NEVER_MATCH_SENTINEL'@::valid:12"
    "list-marker-off::箇条書きのマーカー除去を無効化する::s@^LIST_RE=.*@LIST_RE='NEVER_MATCH_SENTINEL'@::valid:13 valid:20 invalid:12"
    "numbered-paren-off::番号付き項目の丸括弧の形を落とす::s@^LIST_RE=.*@LIST_RE='^([-*+][[:space:]]+|[0-9]+[.][[:space:]]+)'@::valid:20"
    "emphasis-strip-off::強調の記号の除去を無効化する::s@^EMPHASIS_MARKS=.*@EMPHASIS_MARKS=('NEVER_MATCH_SENTINEL')@::valid:14 valid:16"
    "strikethrough-off::二つ続いたチルダの除去だけを落とす::s@^EMPHASIS_MARKS=.*@EMPHASIS_MARKS=('**' '__')@::valid:16"
    'thematic-break-join::箇条書きの直後の区切り線を項目へ折り込む::s@^        if \[ "\$buf_is_list" -eq 1 \] && \[\[ "\$s" =~ \$SETEXT_RE \]\]; then@        if false; then@::valid:25'
)

# 候補の検出条件を無効化する。対応する候補 fixture だけが候補を出さなくなる。
MUTATIONS_CANDIDATE=(
    'identifier-off::不透明な識別子の判定を無効化する::s/^check_identifiers() {$/check_identifiers() {\n    return 0/::candidate:01 candidate:02 candidate:03 candidate:04 candidate:05 invalid:04:候補'
    "identifier-drop-issue::識別子の形から課題番号を落とす::s@^ID_RE=.*@ID_RE='(ADR-[0-9]{8,12}-[0-9]+)'@::candidate:03 invalid:04:候補"
    'identifier-keep-backticks::識別子の判定でインラインコードの囲みを外さない::s@^    naked=.*@    naked="\$sentence"@::candidate:02'
    "drop-particle-ga::骨格位置の助詞から「が」を落とす::s@^SKELETON_PARTICLES=.*@SKELETON_PARTICLES=('は' 'を')@::candidate:04 invalid:04:候補"
    "drop-particle-wo::骨格位置の助詞から「を」を落とす::s@^SKELETON_PARTICLES=.*@SKELETON_PARTICLES=('は' 'が')@::candidate:05"
)

setup_file() {
    common_setup_file
}

# 変異体を作る。置換が空振りした場合は呼び出し側が検出できるよう、元との差を返す。
# sed の終了コードも見る。置換プログラムが壊れていると sed は部分的な出力を残して
# 失敗し、その変異体は全ての fixture で緑になる。差だけを見ると「変異が効いた」と
# 読めてしまい、検査していないことと違反が無いことが区別できなくなる。
build_mutant() {
    local program="$1" out="$2" rc
    sed "$program" "$SUT" >"$out" 2>"$out.err"
    rc="$?"
    if [ "$rc" -ne 0 ]; then
        MUTANT_ERROR="sed が失敗しました（exit $rc）: $(cat "$out.err")"
        return 1
    fi
    if cmp -s "$SUT" "$out"; then
        MUTANT_ERROR="sed が原本を書き換えていない。変異の対象が改名または移動した可能性がある"
        return 1
    fi
    return 0
}

# 変異体（または原本）へ fixture を1件食わせる。種別プロファイルは明示的に渡す。
# 変異体は一時ディレクトリに置かれ、同梱の資源を相対パスで解決できないためである。
run_lint() {
    local script="$1" subdir="$2" fixture="$3"
    run bash "$script" --all \
        --profile "$BUNDLED_PROFILE" \
        "$LINT_FIXTURES/$subdir/$fixture" </dev/null
}

MUTATION_GROUPS=(invalid valid candidate)

# 群ごとの既定の軸。期待は <群>:<接頭辞> で既定の軸を指し、既定でない軸は
# <群>:<接頭辞>:<軸> と書く。片方の軸しか見ないと、終了コードを動かさずに候補だけを
# 消す変異が素通りする。
axis_default() {
    case "$1" in
        candidate) printf '候補' ;;
        *) printf 'rc' ;;
    esac
}

group_fixtures() {
    case "$1" in
        invalid) printf '%s\n' "${NEGATIVES[@]}" ;;
        valid) printf '%s\n' "${POSITIVES[@]}" ;;
        candidate) printf '%s\n' "${CANDIDATES[@]}" ;;
    esac
}

# 変異前の値は宣言で持たず、原本を走らせて測る。宣言で持つと、宣言と実測がずれても
# 気づけない。軸は2つとも測る。
declare -gA BASELINE_RC=()
declare -gA BASELINE_CAND=()

observe() {
    OBS_RC="$status"
    if [[ "$output" == *"[候補: "* ]]; then OBS_CAND="あり"; else OBS_CAND="なし"; fi
}

measure_baselines() {
    local group fixture
    for group in "${MUTATION_GROUPS[@]}"; do
        while IFS= read -r fixture; do
            [ -n "$fixture" ] || continue
            run_lint "$SUT" "$group" "$fixture"
            observe
            BASELINE_RC["$group/$fixture"]="$OBS_RC"
            BASELINE_CAND["$group/$fixture"]="$OBS_CAND"
        done < <(group_fixtures "$group")
    done
    return 0
}

# 軸ごとの「転じた先」。いずれも2値である。
flip_of() {
    local axis="$1" v="$2"
    if [ "$axis" = "rc" ]; then
        if [ "$v" = "0" ]; then printf '1'; else printf '0'; fi
    else
        if [ "$v" = "あり" ]; then printf 'なし'; else printf 'あり'; fi
    fi
}

# 1つの変異表を回す。各変異を3つの群すべてへ、2つの軸すべてで当てる。1つの群・1つの軸に
# しか当てないと、変異が別の群や別の軸まで巻き込んでいることを検出できない。
run_mutation_table() {
    local -n table="$1"

    # 表が空でも失敗バッファは空のままとなり、検査項目0件のケースが ok で通る。
    # 表そのものの縮退をここで検出する。
    if [ "${#table[@]}" -eq 0 ]; then
        collect_fail "変異表 $1 に項目がある" "表が空のため、この向きの検査が1件も走らない"
        return 0
    fi
    collect_ok "変異表 $1 に項目がある"

    local entry key desc program expected mutant group axis
    local fixture prefix want actual base declared
    local judged=0 built=0
    for entry in "${table[@]}"; do
        key="${entry%%::*}"
        entry="${entry#*::}"
        desc="${entry%%::*}"
        entry="${entry#*::}"
        program="${entry%::*}"
        expected="${entry##*::}"

        mutant="$BATS_TEST_TMPDIR/lint-ja-$key.sh"
        if build_mutant "$program" "$mutant"; then
            collect_ok "変異 $key が適用された（$desc）"
            built=$((built + 1))
        else
            # 置換が空振りしていれば以降の判定は無意味になる。ここで止めずに記録し、
            # 全ての変異について空振りの有無を1回の実行で出す。
            collect_fail "変異 $key が適用された（$desc）" "$MUTANT_ERROR"
            continue
        fi

        for group in "${MUTATION_GROUPS[@]}"; do
            while IFS= read -r fixture; do
                [ -n "$fixture" ] || continue
                prefix="${fixture%%-*}"

                run_lint "$mutant" "$group" "$fixture"
                observe

                for axis in rc 候補; do
                    if [ "$axis" = "rc" ]; then
                        base="${BASELINE_RC[$group/$fixture]}"
                        actual="$OBS_RC"
                    else
                        base="${BASELINE_CAND[$group/$fixture]}"
                        actual="$OBS_CAND"
                    fi

                    declared=0
                    if [ "$axis" = "$(axis_default "$group")" ]; then
                        case " $expected " in
                            *" $group:$prefix "*) declared=1 ;;
                        esac
                    fi
                    case " $expected " in
                        *" $group:$prefix:$axis "*) declared=1 ;;
                    esac

                    want="$base"
                    [ "$declared" -eq 1 ] && want="$(flip_of "$axis" "$base")"

                    judged=$((judged + 1))
                    if [ "$actual" = "$want" ]; then
                        collect_ok "変異 $key: $group/$fixture の $axis が $want"
                    elif [ "$declared" -eq 1 ]; then
                        collect_fail "変異 $key: $group/$fixture の $axis が $want" \
                            "条件を無効化しても転じない。この fixture は当該の条件で判定されていない / output: $output"
                    else
                        collect_fail "変異 $key: $group/$fixture の $axis が $want" \
                            "宣言していない fixture まで転じた。変異の射程が広すぎるか、宣言が実測に追いついていない / output: $output"
                    fi
                done
            done < <(group_fixtures "$group")
        done
    done

    # 判定の総数が、変異×fixture×軸の積と一致することを見る。群や軸を1つ落としても
    # 判定が減るだけで全緑のまま通るため、器そのものの縮退はここでしか出ない。
    collect_equals "$judged" \
        "$((built * (${#NEGATIVES[@]} + ${#POSITIVES[@]} + ${#CANDIDATES[@]}) * 2))" \
        "変異表 $1 の判定数が、変異×fixture×軸の積と一致する"
    return 0
}

# 変異表の判定対象が、ディレクトリの実体を覆っているかを見る。配列へ未登録の fixture は
# どの変異の判定にも入らないため、変異の射程外へ黙って落ちる。
collect_mutation_coverage() {
    local group="$1"
    local prev_nullglob present f base label registered
    registered="$(group_fixtures "$group" | tr '\n' ' ')"
    prev_nullglob="$(shopt -p nullglob || true)"
    shopt -s nullglob
    present=("$LINT_FIXTURES/$group"/*.md)
    eval "$prev_nullglob"

    for f in ${present[@]+"${present[@]}"}; do
        base="$(basename "$f")"
        label="$group fixture が変異検査の配列に登録されている: $base"
        case " $registered " in
            *" $base "*) collect_ok "$label" ;;
            *) collect_fail "$label" "未登録のため、どの変異の判定対象にもならない" ;;
        esac
    done
    return 0
}

TRIMMED_CELL=""
trim_cell() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    TRIMMED_CELL="${s%"${s##*[![:space:]]}"}"
}

# 期待の宣言を、文書側の表が使う書き方へ直す。既定でない軸は接尾に括弧で添える。
RENDERED=""
render_expected() {
    local tok group prefix axis label inv="" val="" cand=""
    for tok in $1; do
        group="${tok%%:*}"
        tok="${tok#*:}"
        prefix="${tok%%:*}"
        if [ "$prefix" = "$tok" ]; then axis=""; else axis="${tok#*:}"; fi
        label="$prefix"
        if [ -n "$axis" ] && [ "$axis" != "$(axis_default "$group")" ]; then
            label="$prefix（$axis）"
        fi
        case "$group" in
            invalid) inv="${inv:+$inv・}$label" ;;
            valid) val="${val:+$val・}$label" ;;
            candidate) cand="${cand:+$cand・}$label" ;;
        esac
    done
    RENDERED=""
    [ -n "$inv" ] && RENDERED="負例 $inv"
    [ -n "$val" ] && RENDERED="${RENDERED:+$RENDERED / }正例 $val"
    [ -n "$cand" ] && RENDERED="${RENDERED:+$RENDERED / }候補 $cand"
    return 0
}

# 変異表と、文書側（test-execution.md）の変異表が1対1であることを見る。配列から行を
# 削っても判定対象が減るだけで全緑のまま通り、文書側だけが古くなっても誰も落ちない。
# 説明と期待の両方を突き合わせ、件数と集合の一致を見る。
collect_table_parity() {
    local heading="$1"
    local -n parity_table="$2"

    local -a documented=()
    local line in_table=0 rest cell1 cell2
    while IFS= read -r line; do
        case "$line" in
            "$heading"*)
                in_table=1
                continue
                ;;
        esac
        [ "$in_table" -eq 1 ] || continue
        case "$line" in
            '|'*) ;;
            '') continue ;;
            *)
                in_table=0
                continue
                ;;
        esac
        rest="${line#|}"
        cell1="${rest%%|*}"
        rest="${rest#*|}"
        cell2="${rest%%|*}"
        trim_cell "$cell1"
        cell1="$TRIMMED_CELL"
        trim_cell "$cell2"
        cell2="$TRIMMED_CELL"
        case "$cell1" in
            '変異' | '' | -*) continue ;;
        esac
        documented+=("$cell1｜$cell2")
    done <"$MUTATION_DOC"

    local entry desc row
    local -a declared=()
    for entry in ${parity_table[@]+"${parity_table[@]}"}; do
        entry="${entry#*::}"
        desc="${entry%%::*}"
        render_expected "${entry##*::}"
        declared+=("$desc｜$RENDERED")
    done

    collect_equals "${#documented[@]}" "${#declared[@]}" \
        "$heading の件数が文書側と一致する"

    for row in ${declared[@]+"${declared[@]}"}; do
        case "${documented[*]}" in
            *"$row"*) collect_ok "$heading の行が文書側にもある: $row" ;;
            *) collect_fail "$heading の行が文書側にもある: $row" "文書側の表に同じ行が無い" ;;
        esac
    done
    for row in ${documented[@]+"${documented[@]}"}; do
        case "${declared[*]}" in
            *"$row"*) collect_ok "$heading の文書側の行が変異表にもある: $row" ;;
            *) collect_fail "$heading の文書側の行が変異表にもある: $row" "変異表に同じ行が無い" ;;
        esac
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

    collect_mutation_coverage invalid
    collect_mutation_coverage valid
    collect_mutation_coverage candidate

    collect_finish
}

@test "変異: 検出条件を無効化すると、対応する負例だけが緑へ転じる" {
    collect_init
    measure_baselines
    run_mutation_table MUTATIONS_DETECT
    collect_finish
}

@test "変異: 免除と除外を無効化すると、対応する正例だけが赤へ転じる" {
    collect_init
    measure_baselines
    run_mutation_table MUTATIONS_EXEMPT
    collect_finish
}

@test "変異: 候補の検出条件を無効化すると、対応する候補だけが出なくなる" {
    collect_init
    measure_baselines
    run_mutation_table MUTATIONS_CANDIDATE
    collect_finish
}

@test "変異表が、文書側の変異表と1対1である" {
    collect_init
    collect_table_parity "**検出条件の無効化**" MUTATIONS_DETECT
    collect_table_parity "**免除と除外の無効化**" MUTATIONS_EXEMPT
    collect_table_parity "**候補の検出条件の無効化**" MUTATIONS_CANDIDATE
    collect_finish
}
