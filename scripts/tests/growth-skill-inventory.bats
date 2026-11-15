#!/usr/bin/env bats
# growth の提供物（スキル）の列挙が、実体と食い違っていないことの機械検査。
#
# 【主題】growth のスキルの列挙は2つの文書に在る。配布物の `plugins/growth/README.md` と、
# 配布元の `docs/development/growth/design.md` である。提供物の実体は
# `plugins/growth/skills/` 直下のディレクトリであり、2つの列挙はその射影にあたる。
# 本ファイルは実体と各射影を1対ずつ突き合わせ、名前の集合が一致しなければ赤にする。
# 射影どうしを直接比べない理由は `docs/development/growth/README.md` が持つ。
#
# 【判定の入力】
#   実体      — `plugins/growth/skills/` 直下のディレクトリ名
#   README    — `## 提供物` 見出しの次の行から、次の `## ` 見出しの手前まで。
#               「- **<name> スキル（`skills/<name>/`）**」形の箇条の <name>
#   design.md — `## 4. プラグイン構成` 見出しの次の行から、次の `## ` 見出しの手前まで。
#               「- `<name>` スキル（」形の箇条の <name>（行頭の字下げは問わない）
# 見出しは行全体の一致で探す。<name> は英数字・ハイフン・アンダースコアの並びに限る。
#
# 【届く範囲】照合するのは名前の集合の一致だけである。各スキルの説明文が2つの文書で
# 揃っていることは見ない。同じ名前の箇条が1つの文書に重複していることも見ない。
# README の箇条で `**` の中の名前と `skills/` の後ろの名前が食い違う場合、その箇条は
# 収集されず「箇条が無い」として報告される。
#
# 【fail-closed の向き】見出しの改名・箇条の書式の変更・ファイルの欠落で、ある入力から
# 1件も収集できなくなった場合は、その入力を名指しして赤にする。空集合どうしの一致を
# 合格にしない。
#
# 【負例の作り方】実資産の2文書と `skills/` を一時ディレクトリへ写し、1点だけ変異させる。
# 文書を手書きの fixture にしないのは、実資産の書式が変わったときに、収集の正規表現が
# 追随していないことを正例（実資産で緑）と負例の双方で拾うためである。変異のヘルパは、
# 行がちょうど1行変わったことを自分で確かめる。変異が空振りしたまま判定へ進むと、
# 赤の原因を取り違える。

load 'helpers/common'

README_REL="plugins/growth/README.md"
DESIGN_REL="docs/development/growth/design.md"
SKILLS_REL="plugins/growth/skills"
README_HEADING="## 提供物"
DESIGN_HEADING="## 4. プラグイン構成"

# 節の本文を出す。$1 ファイル / $2 見出し行（行全体の一致）。
# ファイルが無い・見出しが無いときは何も出さない（判定は呼び出し側が空集合として行う）。
section_body() {
    [ -f "$1" ] || return 0
    awk -v heading="$2" '
        $0 == heading { inside = 1; next }
        inside && /^## / { exit }
        inside { print }
    ' "$1"
}

actual_skill_names() {
    local dir
    for dir in "$1/$SKILLS_REL"/*/; do
        [ -d "$dir" ] && basename "$dir"
    done | LC_ALL=C sort -u
}

readme_skill_names() {
    section_body "$1/$README_REL" "$README_HEADING" |
        sed -n 's|^- \*\*\([A-Za-z0-9_-][A-Za-z0-9_-]*\) スキル（`skills/\1/`）\*\*.*|\1|p' |
        LC_ALL=C sort -u
}

design_skill_names() {
    section_body "$1/$DESIGN_REL" "$DESIGN_HEADING" |
        sed -n 's|^[[:space:]]*- `\([A-Za-z0-9_-][A-Za-z0-9_-]*\)` スキル（.*|\1|p' |
        LC_ALL=C sort -u
}

# 実体と1つの射影を突き合わせ、食い違いを1行ずつ出す。食い違いが無ければ何も出さない。
# $1 実体の名前（改行区切り・整列済み） / $2 射影の名前（同） / $3 射影の呼び名
diff_against_actual() {
    local actual="$1" listed="$2" label="$3" name
    if [ -z "$listed" ]; then
        printf '  - %s からスキルの箇条を1件も収集できない\n' "$label"
        return 0
    fi
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        printf '  - %s に箇条が無い: %s\n' "$label" "$name"
    done < <(LC_ALL=C comm -23 <(printf '%s\n' "$actual") <(printf '%s\n' "$listed"))
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        printf '  - %s に箇条が在るが実体が無い: %s\n' "$label" "$name"
    done < <(LC_ALL=C comm -13 <(printf '%s\n' "$actual") <(printf '%s\n' "$listed"))
}

# 比較の本体。$1 はリポジトリのルート（実資産にも一時 fixture にも当てる）。
# 一致すれば 0。食い違い・収集の欠落があれば、全件を出して 1。
check_growth_skill_inventory() {
    local root="$1" actual problems
    actual=$(actual_skill_names "$root")
    if [ -z "$actual" ]; then
        printf 'growth の提供物の実体を収集できません\n'
        printf '  - %s/ 直下にディレクトリが1件も無い\n' "$SKILLS_REL"
        return 1
    fi
    problems=$(
        diff_against_actual "$actual" "$(readme_skill_names "$root")" \
            "$README_REL「$README_HEADING」"
        diff_against_actual "$actual" "$(design_skill_names "$root")" \
            "$DESIGN_REL「$DESIGN_HEADING」"
    )
    if [ -n "$problems" ]; then
        printf 'growth の提供物の列挙が実体（%s/ 直下のディレクトリ名）と一致しません\n' "$SKILLS_REL"
        printf '%s\n' "$problems"
        return 1
    fi
    return 0
}

# ---- fixture と変異 ----

# 実資産の2文書と skills/ を一時ディレクトリへ写し、そのルートを FIXTURE に入れる。
# 写しが変異の前から一致していなければ、ここで落とす。土台が赤いまま変異を重ねると、
# 負例が別の理由で赤くなり、変異を検出したのかどうかを読み分けられない。
make_fixture() {
    FIXTURE="$BATS_TEST_TMPDIR/root"
    mkdir -p "$FIXTURE/plugins/growth" "$FIXTURE/$(dirname "$DESIGN_REL")"
    cp "$REPO_ROOT/$README_REL" "$FIXTURE/$README_REL"
    cp "$REPO_ROOT/$DESIGN_REL" "$FIXTURE/$DESIGN_REL"
    cp -R "$REPO_ROOT/$SKILLS_REL" "$FIXTURE/$SKILLS_REL"
    if ! check_growth_skill_inventory "$FIXTURE" >/dev/null; then
        printf '土台が緑でない（実資産の写しが、変異の前から一致していない）。' >&2
        printf '実資産のケースの報告を先に直す\n' >&2
        return 1
    fi
}

line_count() {
    wc -l <"$1" | tr -d ' '
}

# 固定文字列 $2 を含む行を $1 から消す。ちょうど1行消えたことを確かめる。
remove_line_containing() {
    local file="$1" needle="$2" before after
    before=$(line_count "$file")
    grep -vF -- "$needle" "$file" >"$file.next" || true
    mv "$file.next" "$file"
    after=$(line_count "$file")
    if [ "$((before - after))" -ne 1 ]; then
        printf '変異が空振りした（%s を含む行を1行消すはずが %d 行消えた）: %s\n' \
            "$needle" "$((before - after))" "$file" >&2
        return 1
    fi
}

# 行全体が $2 に一致する最初の行の直後へ $3 を1行足す。ちょうど1行増えたことを確かめる。
insert_line_after() {
    local file="$1" anchor="$2" added="$3" before after
    before=$(line_count "$file")
    awk -v anchor="$anchor" -v added="$added" '
        { print }
        !done && $0 == anchor { print added; done = 1 }
    ' "$file" >"$file.next"
    mv "$file.next" "$file"
    after=$(line_count "$file")
    if [ "$((after - before))" -ne 1 ]; then
        printf '変異が空振りした（%s の直後へ1行足せなかった）: %s\n' "$anchor" "$file" >&2
        return 1
    fi
}

# 行全体が $2 に一致する行を $3 へ置き換える。ちょうど1行置き換わったことを確かめる。
replace_whole_line() {
    local file="$1" from="$2" to="$3" hits
    hits=$(grep -cxF -- "$from" "$file" || true)
    if [ "$hits" -ne 1 ]; then
        printf '変異が空振りした（%s に一致する行が %d 行）: %s\n' "$from" "$hits" "$file" >&2
        return 1
    fi
    awk -v from="$from" -v to="$to" '$0 == from { print to; next } { print }' \
        "$file" >"$file.next"
    mv "$file.next" "$file"
}

readme_bullet() {
    printf -- '- **%s スキル（`skills/%s/`）**: 説明。' "$1" "$1"
}

design_bullet() {
    printf -- '   - `%s` スキル（段）: 説明。' "$1"
}

# ---- 正例 ----

# `run` を介さずに呼ぶ。食い違いの報告を、bats の起動オプションによらず失敗時に出すためである。
@test "実資産: skills/ の実体と README・design.md の列挙が一致する" {
  check_growth_skill_inventory "$REPO_ROOT"
}

@test "実体と2つの文書へ同じスキルを足すと一致する（名前を固定で持っていないこと）" {
  make_fixture
  mkdir "$FIXTURE/$SKILLS_REL/zzz-new"
  insert_line_after "$FIXTURE/$README_REL" "$README_HEADING" "$(readme_bullet zzz-new)"
  insert_line_after "$FIXTURE/$DESIGN_REL" "$DESIGN_HEADING" "$(design_bullet zzz-new)"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "節の外に在る同形の箇条は収集しない（判定の範囲が節に限られること）" {
  make_fixture
  printf '\n## 節の外\n\n%s\n' "$(readme_bullet zzz-outside)" >>"$FIXTURE/$README_REL"
  printf '\n## 節の外\n\n%s\n' "$(design_bullet zzz-outside)" >>"$FIXTURE/$DESIGN_REL"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- 負例 ----

@test "README だけから箇条が1件欠けると赤になり、欠けた名前と側を報告する" {
  make_fixture
  remove_line_containing "$FIXTURE/$README_REL" '- **intake スキル（`skills/intake/`）**'
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$README_REL「$README_HEADING」 に箇条が無い: intake"* ]]
  [[ "$output" != *"$DESIGN_REL"* ]]
}

@test "design.md だけから箇条が1件欠けると赤になり、欠けた名前と側を報告する" {
  make_fixture
  remove_line_containing "$FIXTURE/$DESIGN_REL" '- `intake` スキル（'
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$DESIGN_REL「$DESIGN_HEADING」 に箇条が無い: intake"* ]]
  [[ "$output" != *"$README_REL"* ]]
}

@test "README だけへ実体の無いスキルが足されると赤になる" {
  make_fixture
  insert_line_after "$FIXTURE/$README_REL" "$README_HEADING" "$(readme_bullet zzz-ghost)"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$README_REL「$README_HEADING」 に箇条が在るが実体が無い: zzz-ghost"* ]]
  [[ "$output" != *"$DESIGN_REL"* ]]
}

@test "design.md だけへ実体の無いスキルが足されると赤になる" {
  make_fixture
  insert_line_after "$FIXTURE/$DESIGN_REL" "$DESIGN_HEADING" "$(design_bullet zzz-ghost)"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$DESIGN_REL「$DESIGN_HEADING」 に箇条が在るが実体が無い: zzz-ghost"* ]]
  [[ "$output" != *"$README_REL"* ]]
}

@test "skills/ にディレクトリが増え、どちらの文書にも無いと赤になり、両側を報告する" {
  make_fixture
  mkdir "$FIXTURE/$SKILLS_REL/zzz-unlisted"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$README_REL「$README_HEADING」 に箇条が無い: zzz-unlisted"* ]]
  [[ "$output" == *"$DESIGN_REL「$DESIGN_HEADING」 に箇条が無い: zzz-unlisted"* ]]
}

@test "件数を保ったまま名前だけが入れ替わると赤になる（件数ではなく集合を見ること）" {
  make_fixture
  remove_line_containing "$FIXTURE/$README_REL" '- **intake スキル（`skills/intake/`）**'
  insert_line_after "$FIXTURE/$README_REL" "$README_HEADING" "$(readme_bullet zzz-renamed)"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$README_REL「$README_HEADING」 に箇条が無い: intake"* ]]
  [[ "$output" == *"$README_REL「$README_HEADING」 に箇条が在るが実体が無い: zzz-renamed"* ]]
}

@test "README の見出しが改名されて箇条を収集できないと赤になる" {
  make_fixture
  replace_whole_line "$FIXTURE/$README_REL" "$README_HEADING" "## 提供するもの"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$README_REL「$README_HEADING」 からスキルの箇条を1件も収集できない"* ]]
  [[ "$output" != *"$DESIGN_REL"* ]]
}

@test "design.md の見出しが改名されて箇条を収集できないと赤になる" {
  make_fixture
  replace_whole_line "$FIXTURE/$DESIGN_REL" "$DESIGN_HEADING" "## 4. 構成"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$DESIGN_REL「$DESIGN_HEADING」 からスキルの箇条を1件も収集できない"* ]]
  [[ "$output" != *"$README_REL"* ]]
}

@test "文書のファイルが無いと赤になる（欠落を空集合の一致として通さないこと）" {
  make_fixture
  rm "$FIXTURE/$DESIGN_REL"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$DESIGN_REL「$DESIGN_HEADING」 からスキルの箇条を1件も収集できない"* ]]
}

@test "skills/ にディレクトリが1件も無いと赤になる" {
  make_fixture
  rm -rf "$FIXTURE/$SKILLS_REL"
  mkdir "$FIXTURE/$SKILLS_REL"
  run check_growth_skill_inventory "$FIXTURE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$SKILLS_REL/ 直下にディレクトリが1件も無い"* ]]
}
