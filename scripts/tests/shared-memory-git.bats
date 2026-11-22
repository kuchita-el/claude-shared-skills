#!/usr/bin/env bats
load 'helpers/common'

# shared-memory の検査器のうち、git を使うコマンド（version・adopted）の試験。
# 記憶のリポジトリと台帳は、試験ごとに $BATS_TEST_TMPDIR へ作る。配布物へ fixture を置かない。
# 利用者の git の設定に左右されないよう、設定を読まない環境で git を動かす。

setup() {
  SUT="$REPO_ROOT/plugins/shared-memory/scripts/memory.mjs"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
  UP="$BATS_TEST_TMPDIR/upstream"
  GM="$BATS_TEST_TMPDIR/global"
  PM="$BATS_TEST_TMPDIR/project/docs/memory"
  git init -q -b main "$UP"
  mkdir -p "$UP/records" "$PM/records"
}

A=MEM-202611140000-01
B=MEM-202611140000-02
C=MEM-202611140000-03
D=MEM-202611140000-04
E=MEM-202611140000-05

# 形式に合う記録を1件書く。$1 は記憶の根、$2 は識別子、$3 は名前、$4 以降は front-matter へ足す行。
record() {
  local root="$1" id="$2" name="$3"
  shift 3
  {
    printf '%s\n' '---' "id: $id" 'type: knowledge' "title: $name の主張" 'author: human' \
      'verification: verified' 'confidence: high' 'applies-when: いつでも' 'sources:' '  - 出典' \
      'created: 2026-11-14' 'updated: 2026-11-14'
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    printf '%s\n' '---' '' '本文。'
  } >"$root/records/$id-$name.md"
}

# $1 のリポジトリの変更を全てコミットする。$2 はメッセージ。
commit() {
  git -C "$1" add -A
  git -C "$1" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm "$2"
}

# $1 のリポジトリの、$2（省いたときは HEAD）の省略形（7桁）。
short() {
  git -C "$1" rev-parse --short=7 "${2:-HEAD}"
}

# 上流を全履歴で clone して Global Memory の根にする。$1 以降は clone へ足す引数。
clone_global() {
  git clone -q "$@" "file://$UP" "$GM"
}

# 台帳を1件書く。$1 は記録の識別子、$2 は版。
adopt() {
  mkdir -p "$PM/adopted"
  printf '%s\n' '---' "record: $1" "version: $2" 'decisions:' '  - ADR-202611200000-01' \
    'adopted: 2026-11-21' '---' '' '採用の理由。' >"$PM/adopted/$1.md"
}

# 上流に、1件目で A と B、2件目で B だけ、3件目で無関係なファイルを変えた履歴を作る。
# V1・V2 に、1件目と2件目の省略形を入れる。
three_commits() {
  record "$UP" "$A" first
  record "$UP" "$B" second
  commit "$UP" c1
  V1=$(short "$UP")
  sed -i 's/^本文。$/本文を直した。/' "$UP/records/$B-second.md"
  commit "$UP" c2
  V2=$(short "$UP")
  : >"$UP/other.txt"
  commit "$UP" c3
}

# ---- version ----

@test "version: 全履歴の clone では、記録を最後に変えたコミットを返す" {
  three_commits
  clone_global
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
  [ -z "$stderr" ]
  run --separate-stderr node "$SUT" version "$GM" "$A"
  [ "$output" = "$A@$V1" ]
}

@test "version: 履歴の浅い clone では、版を出さずに exit 2 で止まり、取り直し方を示す" {
  three_commits
  clone_global --depth 1
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"--unshallow"* ]]
}

@test "version: 浅い clone でも、履歴を取り直して --ref FETCH_HEAD を指せば正しい版を返す" {
  three_commits
  clone_global --depth 1
  git -C "$GM" fetch -q --deepen=1000 origin main
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref FETCH_HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 既定のブランチのリモート追跡参照が無く --ref も無いと、HEAD へ落とさず exit 2 で止まる" {
  three_commits
  run --separate-stderr node "$SUT" version "$UP" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"--ref"* ]]
}

@test "version: 解決できない --ref は exit 2 で止まる" {
  three_commits
  run --separate-stderr node "$SUT" version "$UP" "$B" --ref no-such-branch
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"no-such-branch"* ]]
}

@test "version: 起点に無い記録と、起点に2件在る識別子は exit 1 で終わる" {
  three_commits
  git -C "$UP" checkout -q -b topic
  record "$UP" "$C" third
  commit "$UP" topic
  run --separate-stderr node "$SUT" version "$UP" "$C" --ref main
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"$C"* ]]
  # 無いのか、複数在るのかを、標準エラーが分けて述べる。置き換えと下書きの手順が、この2つを判定の入力にする。
  [[ "$stderr" == *"の記録が無い"* ]]
  record "$UP" "$C" other
  commit "$UP" twice
  run --separate-stderr node "$SUT" version "$UP" "$C" --ref topic
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"の記録が複数在る"* ]]
}

@test "version: 作業中のブランチで記録を変えていても、--ref が指す起点のコミットを返す" {
  three_commits
  git -C "$UP" checkout -q -b topic
  sed -i 's/^本文を直した。$/ブランチで直した。/' "$UP/records/$B-second.md"
  commit "$UP" topic
  [ "$(short "$UP")" != "$V2" ]
  run --separate-stderr node "$SUT" version "$UP" "$B" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 名前だけを変えたコミットの後は、そのコミットを返す" {
  three_commits
  git -C "$UP" mv "records/$A-first.md" "records/$A-renamed.md"
  commit "$UP" rename
  run --separate-stderr node "$SUT" version "$UP" "$A" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$A@$(short "$UP")" ]
}

@test "version: git のリポジトリでない根・形に合わない識別子・形に合わない引数は exit 2 で終わる" {
  three_commits
  mkdir -p "$BATS_TEST_TMPDIR/plain/records"
  run --separate-stderr node "$SUT" version "$BATS_TEST_TMPDIR/plain" "$A" --ref main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  local args
  for args in "MEM-1 --ref main" "$A extra" "$A --ref" "$A --ref=main" "$A --ref -main" "$A --ref main extra" ""; do
    # shellcheck disable=SC2086
    run --separate-stderr node "$SUT" version "$UP" $args
    [ "$status" -eq 2 ]
    [ -z "$output" ]
  done
}

@test "version: 履歴を取りに行かない（origin が届かない場所を指していても同じ版を返す）" {
  three_commits
  clone_global
  git -C "$GM" remote set-url origin "file://$BATS_TEST_TMPDIR/no-such-remote"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 作業ツリーの記録が版と違うと、版はそのまま返し、標準エラーへ知らせる" {
  three_commits
  clone_global
  printf '%s\n' '手元の変更。' >>"$GM/records/$B-second.md"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
  [[ "$stderr" == *"records/$B-second.md"* ]]
  rm "$GM/records/$B-second.md"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
  [[ "$stderr" == *"records/$B-second.md"* ]]
}

@test "version: 根がリポジトリの下位のディレクトリでも動き、出力に根の場所を含めない" {
  local repo="$BATS_TEST_TMPDIR/project"
  git init -q -b main "$repo"
  record "$PM" "$A" first
  commit "$repo" c1
  local v1
  v1=$(short "$repo")
  : >"$repo/other.txt"
  commit "$repo" c2
  run --separate-stderr node "$SUT" version "$PM" "$A" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$A@$v1" ]
  [ -z "$stderr" ]
}

# ---- adopted ----

@test "adopted: 採用の後に別の記録だけが変わったときは unchanged" {
  three_commits
  clone_global
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:unchanged: $A@$V1" ]
}

@test "adopted: 名前だけが変わったときは unchanged（内容で比べる）" {
  three_commits
  git -C "$UP" mv "records/$A-first.md" "records/$A-renamed.md"
  commit "$UP" rename
  clone_global
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:unchanged: $A@$V1" ]
}

@test "adopted: 本文が変わったときは changed で、起点での版を右に示す" {
  three_commits
  clone_global
  adopt "$B" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$B.md:changed: $B@$V1 -> $B@$V2" ]
}

@test "adopted: front-matter だけが変わったときも changed" {
  three_commits
  sed -i 's/^verification: verified/verification: unverified/' "$UP/records/$A-first.md"
  commit "$UP" downgrade
  clone_global
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:changed: $A@$V1 -> $A@$(short "$UP")" ]
}

@test "adopted: 置き換えられたときは superseded で、置き換え先を示す（changed と出さない）" {
  three_commits
  sed -i "s/^updated: .*/&\nsuperseded-by: $C/" "$UP/records/$A-first.md"
  record "$UP" "$C" third
  record "$UP" "$E" change 'from:' "  - $A" 'to:' "  - $C"
  sed -i 's/^type: knowledge/type: evolution/' "$UP/records/$E-change.md"
  commit "$UP" supersede
  clone_global
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:superseded: $A@$V1 -> $A@$(short "$UP") superseded-by $C" ]
}

@test "adopted: 記憶の外へ移されたときは moved で、移した先を示す" {
  three_commits
  sed -i 's/^updated: .*/&\nmoved-to: lint の規則 no-foo/' "$UP/records/$A-first.md"
  commit "$UP" move
  clone_global
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:moved: $A@$V1 -> $A@$(short "$UP") moved-to lint の規則 no-foo" ]
}

@test "adopted: 起点に記録が無いときは missing で exit 1" {
  three_commits
  clone_global
  adopt "$D" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$D.md:missing: $D@$V1 "* ]]
}

@test "adopted: 版のコミットが無いときは missing で exit 1" {
  three_commits
  clone_global
  adopt "$A" 0000000
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$A.md:missing: $A@0000000 版のコミットが無い"* ]]
}

@test "adopted: 版が起点の祖先でない（マージの前のブランチのコミット）ときは missing で exit 1" {
  three_commits
  git -C "$UP" checkout -q -b topic
  sed -i 's/^本文。$/ブランチで直した。/' "$UP/records/$A-first.md"
  commit "$UP" topic
  local topic
  topic=$(short "$UP")
  adopt "$A" "$topic"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$A.md:missing: $A@$topic 版が起点の履歴に無い"* ]]
  # 起点を topic にすれば、同じ台帳が unchanged になる（落としているのは祖先の判定である）。
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref topic
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:unchanged: $A@$topic" ]
}

@test "adopted: 版に記録が無い（記録が出来る前のコミット）ときは missing で exit 1" {
  : >"$UP/other.txt"
  commit "$UP" c0
  local v0
  v0=$(short "$UP")
  record "$UP" "$A" first
  commit "$UP" c1
  adopt "$A" "$v0"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$A.md:missing: $A@$v0 版に記録が無い"* ]]
}

@test "adopted: 台帳の全件を、ファイル名の順に1行ずつ出す" {
  three_commits
  record "$UP" "$C" third
  record "$UP" "$D" fourth
  commit "$UP" c4
  local v4
  v4=$(short "$UP")
  sed -i "s/^updated: .*/&\nsuperseded-by: $A/" "$UP/records/$C-third.md"
  record "$UP" "$E" change 'from:' "  - $C" 'to:' "  - $A"
  sed -i 's/^type: knowledge/type: evolution/' "$UP/records/$E-change.md"
  sed -i 's/^updated: .*/&\nmoved-to: 指示ファイル/' "$UP/records/$D-fourth.md"
  commit "$UP" c5
  local v5
  v5=$(short "$UP")
  clone_global
  adopt "$D" "$v4"
  adopt "$C" "$v4"
  adopt "$B" "$V1"
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "adopted/$A.md:unchanged: $A@$V1" ]
  [ "${lines[1]}" = "adopted/$B.md:changed: $B@$V1 -> $B@$V2" ]
  [ "${lines[2]}" = "adopted/$C.md:superseded: $C@$v4 -> $C@$v5 superseded-by $A" ]
  [ "${lines[3]}" = "adopted/$D.md:moved: $D@$v4 -> $D@$v5 moved-to 指示ファイル" ]
}

@test "adopted: Global Memory の履歴が浅いと、何も出さずに exit 2 で止まる" {
  three_commits
  clone_global --depth 1
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"--unshallow"* ]]
}

@test "adopted: 形式の違反が在る台帳は check と同じ行を出して exit 1 とし、ほかの件は判定する" {
  three_commits
  clone_global
  adopt "$A" "$V1"
  adopt "$B" "$V1"
  sed -i '/^version:/d' "$PM/adopted/$A.md"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "adopted/$A.md:required: version が無い" ]
  [ "${lines[1]}" = "adopted/$B.md:changed: $B@$V1 -> $B@$V2" ]
  run node "$SUT" check "$PM"
  [[ "$output" == *"adopted/$A.md:required: version が無い"* ]]
}

@test "adopted: 台帳が無い根と、0件の台帳は、何も出さずに exit 0" {
  three_commits
  clone_global
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  mkdir "$PM/adopted"
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "adopted: Global Memory の作業ツリーを読まない（作業中のブランチの変更に左右されない）" {
  three_commits
  git -C "$UP" checkout -q -b topic
  sed -i 's/^本文。$/ブランチで直した。/' "$UP/records/$A-first.md"
  commit "$UP" topic
  printf '%s\n' '手元の変更。' >>"$UP/records/$A-first.md"
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:unchanged: $A@$V1" ]
}

@test "adopted: 採用した時点で置き換え済みだった記録は、内容が同じでも superseded（判定の順）" {
  three_commits
  sed -i "s/^updated: .*/&\nsuperseded-by: $C/" "$UP/records/$A-first.md"
  commit "$UP" supersede
  local v
  v=$(short "$UP")
  adopt "$A" "$v"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$A.md:superseded: $A@$v -> $A@$v superseded-by $C" ]
}

@test "adopted: 起点の記録の front-matter を読めないときは、内容の違いだけで判定し、その旨を添える" {
  three_commits
  printf '%s\n' '本文だけ。' >"$UP/records/$A-first.md"
  commit "$UP" broken
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 0 ]
  [[ "$output" == "adopted/$A.md:changed: $A@$V1 -> $A@$(short "$UP")"*"front-matter を読めない"* ]]
}

@test "adopted: 記憶の根でない引数と、形に合わない引数は exit 2 で終わる" {
  three_commits
  run --separate-stderr node "$SUT" adopted "$PM"
  [ "$status" -eq 2 ]
  run --separate-stderr node "$SUT" adopted "$PM" "$BATS_TEST_TMPDIR/missing"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"記憶の根がディレクトリでない"* ]]
  mkdir -p "$BATS_TEST_TMPDIR/plain/records"
  run --separate-stderr node "$SUT" adopted "$PM" "$BATS_TEST_TMPDIR/plain" --ref main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref
  [ "$status" -eq 2 ]
}

# ---- 記録の決め方と、git の呼び出し方 ----

@test "adopted: 起点に同じ識別子の記録が2件在るときは missing で exit 1" {
  three_commits
  record "$UP" "$A" other
  commit "$UP" twice
  adopt "$A" "$V1"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [ "$output" = "adopted/$A.md:missing: $A@$V1 起点に記録が複数在る" ]
}

@test "adopted: 版のコミットに同じ識別子の記録が2件在るときは missing で exit 1" {
  record "$UP" "$A" first
  record "$UP" "$A" other
  commit "$UP" c1
  local v1
  v1=$(short "$UP")
  git -C "$UP" rm -q "records/$A-other.md"
  commit "$UP" c2
  adopt "$A" "$v1"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [ "$output" = "adopted/$A.md:missing: $A@$v1 版に記録が複数在る" ]
}

@test "adopted: 版と同じ綴りの名前の ref が在っても、それを版として解決しない" {
  three_commits
  git -C "$UP" tag abcdef1 "$V1"
  adopt "$A" abcdef1
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$A.md:missing: $A@abcdef1 版のコミットが無い"* ]]
}

@test "version: records の直下のディレクトリと、.md で終わらないファイルは、記録に数えない" {
  three_commits
  mkdir "$UP/records/$A-dir.md"
  printf '%s\n' '下の階層。' >"$UP/records/$A-dir.md/inner.md"
  commit "$UP" tree
  run --separate-stderr node "$SUT" version "$UP" "$A" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$A@$V1" ]
  printf '%s\n' '控え。' >"$UP/records/$A-first.md.bak"
  commit "$UP" backup
  run --separate-stderr node "$SUT" version "$UP" "$A" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$A@$V1" ]
}

@test "version: 記録の名前に含まれる * を、パターンとして読まない" {
  record "$UP" "$A" first
  record "$UP" "$A" 'f*'
  commit "$UP" c1
  local v1
  v1=$(short "$UP")
  git -C "$UP" rm -q "records/$A-first.md"
  commit "$UP" c2
  run --separate-stderr node "$SUT" version "$UP" "$A" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$A@$v1" ]
}

@test "version と adopted: 継承した GIT_DIR と GIT_WORK_TREE に左右されず、渡した根のリポジトリを読む" {
  local repo="$BATS_TEST_TMPDIR/project" other="$BATS_TEST_TMPDIR/other"
  git init -q -b main "$repo"
  record "$PM" "$A" first
  commit "$repo" c1
  local v1
  v1=$(short "$repo")
  git init -q -b main "$other"
  : >"$other/other.txt"
  commit "$other" c1
  local variable
  for variable in "GIT_DIR=$other/.git" "GIT_WORK_TREE=$other"; do
    run --separate-stderr env "$variable" node "$SUT" version "$PM" "$A" --ref main
    [ "$status" -eq 0 ]
    [ "$output" = "$A@$v1" ]
  done
  three_commits
  adopt "$B" "$V1"
  run --separate-stderr env "GIT_DIR=$other/.git" node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "adopted/$B.md:changed: $B@$V1 -> $B@$V2" ]
}
