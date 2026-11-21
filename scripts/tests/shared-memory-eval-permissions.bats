#!/usr/bin/env bats
# shared-memory のスキルの許可の一覧と、その写しが食い違っていないことの機械検査。
#
# 【主題】スキルが使う道具の一覧は3か所に在る。正本は、各スキルの SKILL.md の front-matter の
# `allowed-tools` である。写しは2つ在る。eval の挙動ケースの `prompt.md` の `allowed_tools` と、
# 実行ガイド（`docs/development/test-execution.md`）の `--allow-tools` の指定である。
# eval の子セッションには、スキルの `allowed-tools` が付与されないので、写しを無くせない。
# 本ファイルは、正本と各写しを1対ずつ突き合わせ、集合が一致しなければ赤にする。
#
# 【判定の入力】
#   正本     — `plugins/shared-memory/skills/<スキル>/SKILL.md` の front-matter の `allowed-tools:` に
#              続く「  - <値>」の行。行末のコメント（空白と `#` から後ろ）は落とす
#   eval     — `evals/shared-memory/<ケース>/prompt.md` の front-matter の `allowed_tools:` に
#              続く「  - <値>」の行
#   ガイド   — 実行ガイドで、GUIDE_ANCHOR で始まる行より後ろの、最初のコードブロックの中身。
#              単一引用符で囲んだ並びと、空白で区切った語を1件に数える。`--allow-tools` と
#              行末の `\` は数えない
#   対応     — 下の CASES。ケースごとに、対応するスキルと、eval だけが足す道具を宣言する
#
# 【一致の定義】
#   eval     = 対応するスキルの正本 ∪ そのケースに宣言した「eval だけが足す道具」
#   ガイド   = GUIDE_EXTRAS ∪ 全てのスキルの正本のうち `Bash(` で始まるもの
# どちらも集合として等しいことを見る。写しに余分が在っても、不足が在っても赤にする。
# 宣言した「eval だけが足す道具」が写しに無い場合と、正本が既に持つ場合も赤にする。
# 意図した差を、宣言と実体の両方で固定するためである。
# ガイドの GUIDE_ANCHOR の行が述べる対象も見る。「<N>つのスキル」と書いていれば、N が
# スキルの件数と一致すること。そう書いていなければ、全てのスキルを名指していること。
#
# 【届く範囲】見るのは、道具の名前とパターンの文字列の一致である。パターンが、手順の示す
# コマンドに当たるかは見ない。付与した道具で eval が実際に動くかも見ない。
#
# 【fail-closed の向き】ある入力から1件も収集できなければ、その入力を名指しして赤にする。
# 空集合どうしの一致を合格にしない。`evals/shared-memory/` の直下に、対応を宣言していない
# ケースが在る場合も赤にする。ケースを足したときに、検査の外へ黙って落ちないようにする。
#
# 【負例の作り方】実資産を一時ディレクトリへ写し、1点だけ変異させる。手書きの fixture に
# しないのは、実資産の書式が変わったときに、収集が追随していないことを正例と負例の
# 双方で拾うためである。変異のヘルパは、ファイルが変わったことを自分で確かめる。

load 'helpers/common'

SKILLS_REL="plugins/shared-memory/skills"
EVALS_REL="evals/shared-memory"
GUIDE_REL="docs/development/test-execution.md"
GUIDE_ANCHOR='- `shared-memory` は、次の `--allow-tools` を付ける。'

# 「<ケース>|<スキル>|<eval だけが足す道具。空白で区切る>」
# Skill は、依頼文からスキルを起動するために要る。スキル自身の許可には現れない。
CASES=(
    "behavior-propose-records|propose-records|Skill"
)

# ガイドの指定が、Bash パターンのほかに持つ道具。
GUIDE_EXTRAS="Write Edit"

# front-matter の中の、キー $2 の並びの値を、整列して1行ずつ出す。
# ファイルが無い・キーが無いときは何も出さない（判定は呼び出し側が空集合として行う）。
frontmatter_list() {
    [ -f "$1" ] || return 0
    awk -v key="$2" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        $0 == key ":" { inside = 1; next }
        inside && /^  - / {
            line = $0
            sub(/^  - /, "", line)
            sub(/[ \t]+#.*$/, "", line)
            sub(/[ \t]+$/, "", line)
            print line
            next
        }
        inside { inside = 0 }
    ' "$1" | LC_ALL=C sort -u
}

skill_names() {
    local file
    for file in "$1/$SKILLS_REL"/*/SKILL.md; do
        [ -f "$file" ] && basename "$(dirname "$file")"
    done | LC_ALL=C sort -u
}

case_names() {
    local file
    for file in "$1/$EVALS_REL"/*/prompt.md; do
        [ -f "$file" ] && basename "$(dirname "$file")"
    done | LC_ALL=C sort -u
}

guide_anchor_line() {
    [ -f "$1/$GUIDE_REL" ] || return 0
    awk -v anchor="$GUIDE_ANCHOR" 'index($0, anchor) == 1 { print; exit }' "$1/$GUIDE_REL"
}

guide_tools() {
    [ -f "$1/$GUIDE_REL" ] || return 0
    awk -v anchor="$GUIDE_ANCHOR" '
        !armed && index($0, anchor) == 1 { armed = 1; next }
        armed && !inside && /^[ \t]*```/ { inside = 1; next }
        inside && /^[ \t]*```/ { exit }
        inside { print }
    ' "$1/$GUIDE_REL" | tr -d '\\' | { grep -oE "'[^']*'|[^ ']+" || true; } |
        sed "s/^'//; s/'\$//" | { grep -vxF -- '--allow-tools' || true; } | LC_ALL=C sort -u
}

# 2つの集合を突き合わせ、食い違いを1行ずつ出す。
# $1 期待（改行区切り・整列済み） / $2 写し（同） / $3 写しの呼び名 / $4 期待の呼び名
diff_sets() {
    local expected="$1" listed="$2" label="$3" origin="$4" item
    while IFS= read -r item; do
        [ -n "$item" ] || continue
        printf '  - %s に無い（%s に在る）: %s\n' "$label" "$origin" "$item"
    done < <(LC_ALL=C comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$listed"))
    while IFS= read -r item; do
        [ -n "$item" ] || continue
        printf '  - %s に在るが、%s に無い: %s\n' "$label" "$origin" "$item"
    done < <(LC_ALL=C comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$listed"))
}

case_problems() {
    local root="$1" entry case_name skill extras skill_tools eval_tools extra expected
    local declared=""
    for entry in "${CASES[@]}"; do
        IFS='|' read -r case_name skill extras <<<"$entry"
        declared+="$case_name"$'\n'
        skill_tools=$(frontmatter_list "$root/$SKILLS_REL/$skill/SKILL.md" allowed-tools)
        eval_tools=$(frontmatter_list "$root/$EVALS_REL/$case_name/prompt.md" allowed_tools)
        if [ -z "$skill_tools" ]; then
            printf '  - %s/%s/SKILL.md から allowed-tools を1件も収集できない\n' "$SKILLS_REL" "$skill"
            continue
        fi
        if [ -z "$eval_tools" ]; then
            printf '  - %s/%s/prompt.md から allowed_tools を1件も収集できない\n' "$EVALS_REL" "$case_name"
            continue
        fi
        for extra in $extras; do
            if printf '%s\n' "$skill_tools" | grep -qxF -- "$extra"; then
                printf '  - %s が足す道具として宣言した %s を、%s の allowed-tools が既に持つ\n' \
                    "$case_name" "$extra" "$skill"
            fi
        done
        expected=$({ printf '%s\n' "$skill_tools"; printf '%s\n' $extras; } | sed '/^$/d' | LC_ALL=C sort -u)
        diff_sets "$expected" "$eval_tools" "$EVALS_REL/$case_name/prompt.md" \
            "$skill の allowed-tools と宣言した差"
    done
    while IFS= read -r case_name; do
        [ -n "$case_name" ] || continue
        printf '  - %s/%s の対応するスキルが、検査に宣言されていない\n' "$EVALS_REL" "$case_name"
    done < <(LC_ALL=C comm -13 <(printf '%s' "$declared" | LC_ALL=C sort -u) <(case_names "$root"))
}

guide_problems() {
    local root="$1" skills skill union expected listed anchor count stated
    skills=$(skill_names "$root")
    if [ -z "$skills" ]; then
        printf '  - %s/ の直下に SKILL.md が1件も無い\n' "$SKILLS_REL"
        return 0
    fi
    union=$(
        while IFS= read -r skill; do
            frontmatter_list "$root/$SKILLS_REL/$skill/SKILL.md" allowed-tools
        done <<<"$skills" | { grep -F -- 'Bash(' || true; }
    )
    listed=$(guide_tools "$root")
    anchor=$(guide_anchor_line "$root")
    if [ -z "$anchor" ] || [ -z "$listed" ]; then
        printf '  - %s から shared-memory の --allow-tools の指定を収集できない\n' "$GUIDE_REL"
        return 0
    fi
    expected=$({ printf '%s\n' "$union"; printf '%s\n' $GUIDE_EXTRAS; } | sed '/^$/d' | LC_ALL=C sort -u)
    diff_sets "$expected" "$listed" "$GUIDE_REL の --allow-tools" \
        "スキルの allowed-tools の Bash パターンと $GUIDE_EXTRAS"
    count=$(printf '%s\n' "$skills" | wc -l | tr -d ' ')
    stated=$(printf '%s\n' "$anchor" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)つのスキル.*/\1/p')
    if [ -n "$stated" ]; then
        if [ "$stated" != "$count" ]; then
            printf '  - %s が述べるスキルの件数（%s）が、実体の件数（%s）と一致しない\n' \
                "$GUIDE_REL" "$stated" "$count"
        fi
    else
        while IFS= read -r skill; do
            case "$anchor" in
                *"\`$skill\`"*) ;;
                *) printf '  - %s の指定の説明が、スキル %s を名指していない\n' "$GUIDE_REL" "$skill" ;;
            esac
        done <<<"$skills"
    fi
}

# 比較の本体。$1 はリポジトリのルート（実資産にも一時 fixture にも当てる）。
# 一致すれば 0。食い違い・収集の欠落があれば、全件を出して 1。
check_permissions() {
    local root="$1" problems
    problems=$(
        case_problems "$root"
        guide_problems "$root"
    )
    if [ -n "$problems" ]; then
        printf 'shared-memory の許可の一覧の写しが、正本（SKILL.md の allowed-tools）と一致しません\n'
        printf '%s\n' "$problems"
        return 1
    fi
    return 0
}

# ---- fixture と変異 ----

# 実資産を一時ディレクトリへ写し、そのルートを FIXTURE に入れる。
# 写しが変異の前から一致していなければ、ここで落とす。
make_fixture() {
    local file
    FIXTURE="$BATS_TEST_TMPDIR/root"
    mkdir -p "$FIXTURE/$(dirname "$GUIDE_REL")"
    cp "$REPO_ROOT/$GUIDE_REL" "$FIXTURE/$GUIDE_REL"
    for file in "$REPO_ROOT/$SKILLS_REL"/*/SKILL.md "$REPO_ROOT/$EVALS_REL"/*/prompt.md; do
        [ -f "$file" ] || continue
        mkdir -p "$FIXTURE/$(dirname "${file#"$REPO_ROOT"/}")"
        cp "$file" "$FIXTURE/${file#"$REPO_ROOT"/}"
    done
    if ! check_permissions "$FIXTURE" >/dev/null; then
        printf '土台が緑でない（実資産の写しが、変異の前から一致していない）。' >&2
        printf '実資産のケースの報告を先に直す\n' >&2
        return 1
    fi
}

# sed の式 $2 を $1 に当てる。ファイルが変わったことを確かめる。
mutate() {
    local file="$1" expr="$2"
    sed "$expr" "$file" >"$file.next"
    if cmp -s "$file" "$file.next"; then
        printf '変異が空振りした（%s が変わらなかった）: %s\n' "$file" "$expr" >&2
        return 1
    fi
    mv "$file.next" "$file"
}

SKILL_FILE="$SKILLS_REL/propose-records/SKILL.md"
EVAL_FILE="$EVALS_REL/behavior-propose-records/prompt.md"

# ---- 実資産 ----

@test "実資産: eval とガイドの許可の一覧は、スキルの allowed-tools と一致する" {
    run check_permissions "$REPO_ROOT"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
    [ -z "$output" ]
}

@test "実資産: 収集した集合は空でなく、行末のコメントを含まない" {
    run frontmatter_list "$REPO_ROOT/$SKILL_FILE" allowed-tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bash(grep -i -F *)"* ]]
    [[ "$output" != *"#"* ]]
    run guide_tools "$REPO_ROOT"
    [[ "$output" == *"Bash(node *scripts/memory.mjs*)"* ]]
    [[ "$output" != *"--allow-tools"* ]]
    [[ "$output" != *"'"* ]]
}

# ---- 写しの余分と不足 ----

@test "変異: eval に、スキルに無い道具を足すと赤になる" {
    make_fixture
    mutate "$FIXTURE/$EVAL_FILE" 's/^allowed_tools:$/&\n  - Grep/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVAL_FILE に在るが、propose-records の allowed-tools と宣言した差 に無い: Grep"* ]]
}

@test "変異: eval から、スキルが持つパターンを消すと赤になる" {
    make_fixture
    mutate "$FIXTURE/$EVAL_FILE" '/^  - Bash(date -u\*)$/d'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVAL_FILE に無い（propose-records の allowed-tools と宣言した差 に在る）: Bash(date -u*)"* ]]
}

@test "変異: 件数を保ったまま eval のパターンを書き換えても赤になる" {
    make_fixture
    mutate "$FIXTURE/$EVAL_FILE" 's/^  - Bash(date -u\*)$/  - Bash(date *)/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"に無い（propose-records の allowed-tools と宣言した差 に在る）: Bash(date -u*)"* ]]
    [[ "$output" == *"に在るが、propose-records の allowed-tools と宣言した差 に無い: Bash(date *)"* ]]
}

@test "変異: スキルに道具を足して写しを直さないと、eval とガイドの両方で赤になる" {
    make_fixture
    mutate "$FIXTURE/$SKILL_FILE" 's/^allowed-tools:$/&\n  - Bash(git fetch*)   # 説明/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVAL_FILE に無い（propose-records の allowed-tools と宣言した差 に在る）: Bash(git fetch*)"* ]]
    [[ "$output" == *"$GUIDE_REL の --allow-tools に無い"*": Bash(git fetch*)"* ]]
    [[ "$output" != *"説明"* ]]
}

# ---- 宣言した差の側 ----

@test "変異: 宣言した「eval だけが足す道具」を eval から消すと赤になる" {
    make_fixture
    mutate "$FIXTURE/$EVAL_FILE" '/^  - Skill$/d'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVAL_FILE に無い（propose-records の allowed-tools と宣言した差 に在る）: Skill"* ]]
}

@test "変異: 宣言した「eval だけが足す道具」をスキルが持つようになると赤になる" {
    make_fixture
    mutate "$FIXTURE/$SKILL_FILE" 's/^allowed-tools:$/&\n  - Skill/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"behavior-propose-records が足す道具として宣言した Skill を、propose-records の allowed-tools が既に持つ"* ]]
}

# ---- ガイド ----

@test "変異: ガイドの指定からパターンを消すと赤になる" {
    make_fixture
    mutate "$FIXTURE/$GUIDE_REL" "s/ 'Bash(date -u\\*)'//"
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$GUIDE_REL の --allow-tools に無い"*": Bash(date -u*)"* ]]
}

@test "変異: ガイドの指定に、Bash パターンでも宣言した道具でもないものを足すと赤になる" {
    make_fixture
    mutate "$FIXTURE/$GUIDE_REL" 's/--allow-tools Write Edit '"'"'Bash(node/--allow-tools Write Edit Agent '"'"'Bash(node/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$GUIDE_REL の --allow-tools に在るが、"*"に無い: Agent"* ]]
}

@test "変異: スキルを足して、ガイドの説明が述べる対象を直さないと赤になる" {
    make_fixture
    mkdir -p "$FIXTURE/$SKILLS_REL/added-skill"
    cp "$FIXTURE/$SKILL_FILE" "$FIXTURE/$SKILLS_REL/added-skill/SKILL.md"
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$GUIDE_REL の指定の説明が、スキル added-skill を名指していない"* ]]
}

# ---- 収集の欠落 ----

@test "変異: eval の allowed_tools を収集できないと、合格にせず名指しして赤になる" {
    make_fixture
    mutate "$FIXTURE/$EVAL_FILE" 's/^allowed_tools:$/allowed-tools:/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVAL_FILE から allowed_tools を1件も収集できない"* ]]
}

@test "変異: スキルの allowed-tools を収集できないと、合格にせず名指しして赤になる" {
    make_fixture
    mutate "$FIXTURE/$SKILL_FILE" 's/^allowed-tools:$/tools:/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$SKILL_FILE から allowed-tools を1件も収集できない"* ]]
}

@test "変異: ガイドの指定の行が無くなると、合格にせず名指しして赤になる" {
    make_fixture
    mutate "$FIXTURE/$GUIDE_REL" 's/^- `shared-memory` は、次の `--allow-tools` を付ける。/- `shared-memory` は、次を付ける。/'
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$GUIDE_REL から shared-memory の --allow-tools の指定を収集できない"* ]]
}

@test "変異: 対応を宣言していないケースが在ると赤になる" {
    make_fixture
    mkdir -p "$FIXTURE/$EVALS_REL/behavior-undeclared"
    cp "$FIXTURE/$EVAL_FILE" "$FIXTURE/$EVALS_REL/behavior-undeclared/prompt.md"
    run check_permissions "$FIXTURE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$EVALS_REL/behavior-undeclared の対応するスキルが、検査に宣言されていない"* ]]
}
