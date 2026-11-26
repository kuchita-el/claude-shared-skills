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
# 版を求める前の取り直し（git fetch origin main）まで行う。clone しただけの checkout は、検査器が拒む。
clone_global() {
  git clone -q "$@" "file://$UP" "$GM"
  git -C "$GM" fetch -q origin main
}

# $1 のリポジトリの remote 追跡の ref（origin/main）を、上流の $2 のコミットへ戻す。取り直した結果（FETCH_HEAD）は変えない。
rewind_tracking() {
  git -C "$1" update-ref refs/remotes/origin/main "$(git -C "$UP" rev-parse "$2")"
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
  [[ "$stderr" == *"git fetch --deepen=1000 origin main"* ]]
  # 引数なしの --unshallow は、全履歴の clone で失敗する。どちらの clone でも通る形だけを示す。
  [[ "$stderr" != *"--unshallow"* ]]
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
  # クラウドの checkout では、取り直しても既定の起点が無いことがある。ネットワークに出ずに作る方法を示す。
  [[ "$stderr" == *"git remote set-head origin"* ]]
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

@test "version: 履歴を取りに行かない（取り直した後に上流を消しても、同じ版を返す）" {
  three_commits
  clone_global
  mv "$UP" "$BATS_TEST_TMPDIR/moved"
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

# ---- 起点と、最後に取り直した結果との照合 ----

@test "version: 取り直した後に remote 追跡の ref が古くなると、誤った版を返さず exit 2 で止まり、取り直し方を示す" {
  three_commits
  clone_global
  # 再現: ref だけを、B を直す前（c1）へ戻す。照合が無ければ、誤った版 $B@$V1 が exit 0 で返る。
  rewind_tracking "$GM" HEAD~2
  local ref
  for ref in refs/remotes/origin/main origin/main; do
    run --separate-stderr node "$SUT" version "$GM" "$B" --ref "$ref"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"git fetch origin main"* ]]
  done
  # --ref を省いたときの refs/remotes/origin/HEAD も、解決した先（origin/main）で照合する。
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch origin main"* ]]
}

@test "version: 古い ref に無い、マージ済みの記録は、「無い」（exit 1）ではなく exit 2 で止まる" {
  three_commits
  clone_global
  record "$UP" "$C" third
  commit "$UP" c4
  git -C "$GM" fetch -q origin main
  rewind_tracking "$GM" HEAD~1
  run --separate-stderr node "$SUT" version "$GM" "$C" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" != *"の記録が無い"* ]]
}

@test "version: 記録が変わっていなくても、起点が古ければ exit 2 で止まる（結果ではなく起点で判定する）" {
  three_commits
  clone_global
  : >"$UP/later.txt"
  commit "$UP" c4
  git -C "$GM" fetch -q origin main
  rewind_tracking "$GM" HEAD~1
  # A は c1 から変わっていないので、古い起点から数えても版は同じ $A@$V1 になる。それでも止める。
  run --separate-stderr node "$SUT" version "$GM" "$A" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "version: clone しただけで取り直していない checkout は、--ref を省いても exit 2 で止まる" {
  three_commits
  git clone -q "file://$UP" "$GM"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"FETCH_HEAD"* ]]
  [[ "$stderr" == *"git fetch origin main"* ]]
}

@test "version: 別の枝だけを取り直した後は、既定のブランチの ref を起点にすると exit 2 で止まる" {
  three_commits
  git -C "$UP" branch topic HEAD~1
  clone_global
  git -C "$GM" fetch -q origin topic
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  # 取り直した枝の ref なら通る。
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/topic
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 複数の枝を取り直した FETCH_HEAD を --ref FETCH_HEAD で指すと exit 2 で止まり、remote 追跡の ref なら通る" {
  three_commits
  git -C "$UP" branch topic HEAD~2
  clone_global
  # 引数なしの fetch は、全ての枝を FETCH_HEAD へ書く。FETCH_HEAD は、どの枝を指すかが設定に左右される。
  git -C "$GM" fetch -q
  [ "$(grep -c "branch '" "$(git -C "$GM" rev-parse --absolute-git-dir)/FETCH_HEAD")" -eq 2 ]
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref FETCH_HEAD
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"FETCH_HEAD"* ]]
  local ref
  for ref in refs/remotes/origin/main ""; do
    # shellcheck disable=SC2086
    run --separate-stderr node "$SUT" version "$GM" "$B" ${ref:+--ref "$ref"}
    [ "$status" -eq 0 ]
    [ "$output" = "$B@$V2" ]
  done
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/topic
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V1" ]
}

@test "version: 上流が進んだ後に git fetch origin main で取り直せば、省略時も remote 追跡の ref も新しい版を返す" {
  three_commits
  clone_global
  sed -i 's/^本文を直した。$/もう一度直した。/' "$UP/records/$B-second.md"
  commit "$UP" c4
  local v4
  v4=$(short "$UP")
  git -C "$GM" fetch -q origin main
  local ref
  for ref in refs/remotes/origin/main origin/main ""; do
    # shellcheck disable=SC2086
    run --separate-stderr node "$SUT" version "$GM" "$B" ${ref:+--ref "$ref"}
    [ "$status" -eq 0 ]
    [ "$output" = "$B@$v4" ]
  done
}

@test "version: ローカルのブランチを起点に渡すと、取り直した結果と照合しない" {
  three_commits
  git clone -q "file://$UP" "$GM"
  # 取り直していない（FETCH_HEAD が無い）checkout でも、ローカルのブランチ main なら通る。
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref main
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: linked worktree では、その worktree の FETCH_HEAD と照合する" {
  three_commits
  clone_global
  local wt="$BATS_TEST_TMPDIR/global-wt"
  git -C "$GM" worktree add -q "$wt" -b work
  # 元の checkout で取り直した結果は、linked worktree の照合に数えない。
  run --separate-stderr node "$SUT" version "$wt" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  git -C "$wt" fetch -q origin main
  run --separate-stderr node "$SUT" version "$wt" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 別の remote から同じ名前の枝を取り直しただけでは、古い remote 追跡の ref を通さない" {
  three_commits
  local fork="$BATS_TEST_TMPDIR/fork"
  git clone -q "file://$UP" "$fork"
  git clone -q "file://$fork" "$GM"
  git -C "$GM" remote add upstream "file://$UP"
  git -C "$GM" fetch -q origin main
  git -C "$GM" fetch -q upstream main
  # fork の main だけを進め、upstream の main だけを取り直す。FETCH_HEAD は upstream の main の1行になる。
  sed -i 's/^本文を直した。$/fork で直した。/' "$fork/records/$B-second.md"
  commit "$fork" fork
  git -C "$GM" fetch -q upstream main
  [ "$(git -C "$GM" rev-parse refs/remotes/origin/main)" = "$(git -C "$UP" rev-parse HEAD)" ]
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch origin main"* ]]
  git -C "$GM" fetch -q origin main
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/main
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$(short "$fork")" ]
  # upstream の ref は、upstream から取り直した行と照合する。
  git -C "$GM" fetch -q upstream main
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/upstream/main
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 取り直した後に origin の URL を別の場所へ変えると exit 2 で止まり、新しい場所から取り直せば通る" {
  three_commits
  clone_global
  local other="$BATS_TEST_TMPDIR/other.git"
  git clone -q --bare "file://$UP" "$other"
  git -C "$GM" remote set-url origin "file://$other"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  git -C "$GM" fetch -q origin main
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: URL は、末尾の / と .git の有無の違いを除いて比べる" {
  three_commits
  local bare="$BATS_TEST_TMPDIR/bare"
  git clone -q --bare "file://$UP" "$bare.git"
  # git は、FETCH_HEAD へ書く URL から末尾の / と .git を落とす。設定の URL は、そのまま残る。
  git clone -q "file://$bare.git/" "$GM"
  git -C "$GM" fetch -q origin main
  [[ "$(cat "$GM/.git/FETCH_HEAD")" == *" of file://$bare" ]]
  local url
  for url in "file://$bare.git/" "file://$bare.git" "file://$bare" "file://$bare/"; do
    git -C "$GM" remote set-url origin "$url"
    run --separate-stderr node "$SUT" version "$GM" "$B"
    [ "$status" -eq 0 ]
    [ "$output" = "$B@$V2" ]
  done
  # 作業ツリーを持つリポジトリの .git を指す URL では、.git を落とした後に / が残る。
  rm -rf "$GM"
  git clone -q "file://$UP/.git" "$GM"
  git -C "$GM" fetch -q origin main
  [[ "$(cat "$GM/.git/FETCH_HEAD")" == *" of file://$UP/" ]]
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: insteadOf で書き換える remote は、書き換えた後の URL で比べる" {
  three_commits
  git -c "url.file://$BATS_TEST_TMPDIR/.insteadOf=mirror:" clone -q mirror:upstream "$GM"
  git -C "$GM" config "url.file://$BATS_TEST_TMPDIR/.insteadOf" mirror:
  git -C "$GM" fetch -q origin main
  [ "$(git -C "$GM" config remote.origin.url)" = mirror:upstream ]
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: remote の URL の認証情報は、比べる前に除く" {
  three_commits
  clone_global
  # git は、FETCH_HEAD へ書く URL から認証情報を除く。届かない URL は取り直せないので、取り直した後と同じ行を書く。
  local fetch_head commit
  fetch_head="$(git -C "$GM" rev-parse --absolute-git-dir)/FETCH_HEAD"
  commit=$(git -C "$UP" rev-parse HEAD)
  local pair
  for pair in "https://user:secret@example.invalid/team/repo.git|https://example.invalid/team/repo" \
    "git@example.invalid:team/repo.git|example.invalid:team/repo"; do
    git -C "$GM" remote set-url origin "${pair%%|*}"
    printf '%s\t\tbranch %s of %s\n' "$commit" "'main'" "${pair#*|}" >"$fetch_head"
    run --separate-stderr node "$SUT" version "$GM" "$B"
    [ "$status" -eq 0 ]
    [ "$output" = "$B@$V2" ]
  done
  # 認証情報を除いても、ホストが違えば通さない。
  printf '%s\t\tbranch %s of %s\n' "$commit" "'main'" "https://example.invalid/other/repo" >"$fetch_head"
  git -C "$GM" remote set-url origin "https://user:secret@example.invalid/team/repo.git"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "version: / を含む名前の remote は、名前の全体で決める（最初の / で切らない）" {
  three_commits
  local fork="$BATS_TEST_TMPDIR/fork"
  git clone -q "file://$UP" "$fork"
  sed -i 's/^本文を直した。$/fork で直した。/' "$fork/records/$B-second.md"
  commit "$fork" fork
  git init -q -b main "$GM"
  mkdir "$GM/records"
  # 新しい git は、互いに接頭辞になる remote の名前（team と team/fork）を作らせない。team は持たせない。
  git -C "$GM" remote add team/fork "file://$fork"
  git -C "$GM" fetch -q team/fork main
  # refs/remotes/team/fork/main は、remote team の枝 fork/main ではなく、remote team/fork の枝 main である。
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/team/fork/main
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$(short "$fork")" ]
}

@test "version: refspec の外の枝は、remote 追跡の ref が作られないので、FETCH_HEAD を起点にするよう案内する" {
  three_commits
  git -C "$UP" branch topic HEAD~2
  git clone -q --single-branch --branch topic "file://$UP" "$GM"
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch origin main で取り直してから、--ref FETCH_HEAD を渡す"* ]]
  git -C "$GM" fetch -q origin main
  ! git -C "$GM" rev-parse --verify -q refs/remotes/origin/main
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"そのまま --ref FETCH_HEAD で実行し直せる"* ]]
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref FETCH_HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: refspec の外に残った古い remote 追跡の ref には、取り直しではなく FETCH_HEAD を案内する" {
  three_commits
  git -C "$UP" branch topic HEAD~2
  git clone -q --single-branch --branch topic "file://$UP" "$GM"
  git -C "$GM" update-ref refs/remotes/origin/main "$(git -C "$UP" rev-parse HEAD~2)"
  git -C "$GM" fetch -q origin main
  # 取り直しても、refspec の外の ref は進まない。
  [ "$(git -C "$GM" rev-parse refs/remotes/origin/main)" = "$(git -C "$UP" rev-parse HEAD~2)" ]
  run --separate-stderr node "$SUT" version "$GM" "$B" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"そのまま --ref FETCH_HEAD で実行し直せる"* ]]
  [[ "$stderr" != *"取り直してから実行する"* ]]
}

@test "version: シンボリックでない refs/remotes/origin/HEAD は exit 2 で止まり、案内どおり set-head すれば通る" {
  three_commits
  clone_global
  git -C "$GM" symbolic-ref --delete refs/remotes/origin/HEAD
  git -C "$GM" update-ref refs/remotes/origin/HEAD "$(git -C "$UP" rev-parse HEAD)"
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git remote set-head origin"* ]]
  git -C "$GM" remote set-head origin main
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "adopted: Global Memory の remote 追跡の ref が取り直した結果より古いと、何も出さずに exit 2 で止まる" {
  three_commits
  clone_global
  adopt "$A" "$V1"
  rewind_tracking "$GM" HEAD~1
  run --separate-stderr node "$SUT" adopted "$PM" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch origin main"* ]]
  run --separate-stderr node "$SUT" adopted "$PM" "$GM" --ref refs/remotes/origin/main
  [ "$status" -eq 2 ]
  [ -z "$output" ]
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
  [[ "$stderr" == *"git fetch --deepen=1000 origin main"* ]]
  # 引数なしの --unshallow は、全履歴の clone で失敗する。どちらの clone でも通る形だけを示す。
  [[ "$stderr" != *"--unshallow"* ]]
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

# ---- version の候補 ----

# 形式に合う候補を、$1 の記憶の根の candidates/ へ1件書く。$2 は識別子、$3 は名前。
candidate() {
  mkdir -p "$1/candidates"
  printf '%s\n' '---' "id: $2" 'type: knowledge' "title: $3 の主張" 'author: ai' 'verification: unverified' \
    'confidence: medium' 'applies-when: いつでも' 'sources:' '  - 2026-11-20 に手元で実測した' \
    'created: 2026-11-20' 'updated: 2026-11-20' '---' '' '本文。' >"$1/candidates/$2-$3.md"
}

@test "version: candidates の候補は、版の後ろに candidate を足して返し、records の記録はいまの形で返す" {
  three_commits
  candidate "$UP" "$C" arrived
  commit "$UP" c4
  local v4
  v4=$(short "$UP")
  : >"$UP/later.txt"
  commit "$UP" c5
  clone_global
  run --separate-stderr node "$SUT" version "$GM" "$C"
  [ "$status" -eq 0 ]
  [ "$output" = "$C@$v4 candidate" ]
  [ -z "$stderr" ]
  run --separate-stderr node "$SUT" version "$GM" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "$B@$V2" ]
}

@test "version: 起点の records と candidates の両方に同じ識別子が在ると、1件に決まらず exit 1 で終わる" {
  three_commits
  candidate "$UP" "$A" arrived
  commit "$UP" c4
  run --separate-stderr node "$SUT" version "$UP" "$A" --ref main
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"の記録が複数在る"* ]]
  [[ "$stderr" == *"records/$A-first.md"* ]]
  [[ "$stderr" == *"candidates/$A-arrived.md"* ]]
}

@test "version: 作業ツリーの候補が版と違うと、版はそのまま返し、標準エラーへ知らせる" {
  three_commits
  candidate "$UP" "$C" arrived
  commit "$UP" c4
  local v4
  v4=$(short "$UP")
  clone_global
  printf '%s\n' '手元の変更。' >>"$GM/candidates/$C-arrived.md"
  run --separate-stderr node "$SUT" version "$GM" "$C"
  [ "$status" -eq 0 ]
  [ "$output" = "$C@$v4 candidate" ]
  [[ "$stderr" == *"candidates/$C-arrived.md"* ]]
}

@test "adopted: 候補は採用の対象にせず、candidates に在っても missing で exit 1" {
  three_commits
  candidate "$UP" "$C" arrived
  commit "$UP" c4
  adopt "$C" "$(short "$UP")"
  run --separate-stderr node "$SUT" adopted "$PM" "$UP" --ref main
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$C.md:missing: "*"版に記録が無い"* ]]
}

# ---- carry ----

# プロジェクトのリポジトリ。上流（PUP）の docs/memory を記憶の根にし、clone（PJ）から運ぶ。
# 根をリポジトリの下位に置き、パスを根からの相対で扱うことも確かめる。
PUP_NAME=project-upstream
PJ_NAME=project-clone
D1=MEM-202611200000-01
D2=MEM-202611200000-02
D3=MEM-202611200000-03

# 上流のプロジェクトを作る。記憶の根に空の records/ を置き、最初のコミットまで行う。
init_project() {
  PUP="$BATS_TEST_TMPDIR/$PUP_NAME"
  PJ="$BATS_TEST_TMPDIR/$PJ_NAME"
  PROOT="$PJ/docs/memory"
  git init -q -b main "$PUP"
  mkdir -p "$PUP/docs/memory/records" "$PUP/docs/memory/outbox"
  : >"$PUP/docs/memory/records/.gitkeep"
  commit "$PUP" p0
}

# 下書きを1件書く。$1 は outbox/ を持つ記憶の根、$2 は識別子、$3 は名前、$4 は本文。
# 改行は LF にする（下書きと候補は LF だけ）。末尾の改行の無い行を混ぜ、写したものがバイトの単位で同じかを見る。
draft_in() {
  mkdir -p "$1/outbox"
  printf '%s\n' '---' "id: $2" 'type: knowledge' "title: $3 の主張" 'author: ai' 'verification: unverified' \
    'confidence: medium' 'applies-when: いつでも' 'sources:' '  - 2026-11-20 に手元で実測した' \
    'created: 2026-11-20' 'updated: 2026-11-20' '---' '' >"$1/outbox/$2-$3.md"
  printf '%s' "${4:-本文。}" >>"$1/outbox/$2-$3.md"
}

# 上流のプロジェクトを clone し、取り直す。
clone_project() {
  git clone -q "$@" "file://$PUP" "$PJ"
  git -C "$PJ" fetch -q origin main
}

# 上流の Global Memory に記録を1件置いて clone し、取り直す。運ぶ試験の Global Memory の既定の形である。
global_with_record() {
  record "$UP" "$A" first
  commit "$UP" g1
  clone_global
}

@test "carry: 起点の outbox の下書きを、Global の作業ツリーの candidates へバイトの単位で同じに写す" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  draft_in "$PUP/docs/memory" "$D2" second '末尾に改行の無い本文'
  mkdir -p "$PUP/docs/memory/outbox/reports"
  printf '%s\n' '送り出しの報告。' >"$PUP/docs/memory/outbox/reports/$D1.md"
  commit "$PUP" p1
  clone_project
  global_with_record
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$output" = "$(printf '%s\n' "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" "outbox/$D2-second.md:copied: candidates/$D2-second.md へ写した")" ]
  cmp "$PUP/docs/memory/outbox/$D1-first.md" "$GM/candidates/$D1-first.md"
  cmp "$PUP/docs/memory/outbox/$D2-second.md" "$GM/candidates/$D2-second.md"
  # 送り出しの報告（outbox の下の階層）は写さない。
  [ "$(ls -A "$GM/candidates")" = "$(printf '%s\n' "$D1-first.md" "$D2-second.md")" ]
  # commit はしない。
  [ "$(git -C "$GM" rev-parse HEAD)" = "$(git -C "$UP" rev-parse HEAD)" ]
}

@test "carry: 写した後にもう一度運ぶと、同じバイトのファイルは書き直さず copied とする（冪等）" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  run node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md に同じ内容のファイルが既に在る" ]
  cmp "$PUP/docs/memory/outbox/$D1-first.md" "$GM/candidates/$D1-first.md"
}

@test "carry: Global の作業ツリーの同じパスに違うバイトのファイルが在ると、書かずに stopped で exit 1" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  mkdir -p "$GM/candidates"
  printf '%s\n' '手元の別の内容。' >"$GM/candidates/$D1-first.md"
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 1 ]
  [ "$output" = "outbox/$D1-first.md:stopped: Global Memory の作業ツリーの candidates/$D1-first.md が、下書きと内容が違う。書かない" ]
  [ "$(cat "$GM/candidates/$D1-first.md")" = '手元の別の内容。' ]
}

@test "carry: 運んで取り込まれた後も outbox に残っている下書きは、carried として写さない" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  run node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  # Global の CI が取り込んだ形を、上流へ同じファイルをコミットして作る。
  mkdir -p "$UP/candidates"
  cp "$GM/candidates/$D1-first.md" "$UP/candidates/"
  commit "$UP" g2
  rm -rf "$GM/candidates"
  git -C "$GM" fetch -q origin main
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:carried: 同じ内容のファイルが Global Memory の履歴に在る: candidates/$D1-first.md" ]
  [ ! -e "$GM/candidates" ]
}

@test "carry: 選別で捨てて Global の今のツリーに無い候補も、履歴に在れば carried として運び直さない" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  draft_in "$PUP/docs/memory" "$D2" second
  commit "$PUP" p1
  clone_project
  record "$UP" "$A" first
  # D1: 既定のブランチで足して、後で捨てた。
  mkdir -p "$UP/candidates"
  cp "$PUP/docs/memory/outbox/$D1-first.md" "$UP/candidates/"
  commit "$UP" g1
  git -C "$UP" rm -q "candidates/$D1-first.md"
  commit "$UP" g2
  # D2: 枝の上で足して捨て、マージした。パスで絞った履歴の単純化では、この枝が見えなくなる。
  git -C "$UP" checkout -q -b triage
  mkdir -p "$UP/candidates"
  cp "$PUP/docs/memory/outbox/$D2-second.md" "$UP/candidates/"
  commit "$UP" g3
  git -C "$UP" rm -q "candidates/$D2-second.md"
  commit "$UP" g4
  git -C "$UP" checkout -q main
  : >"$UP/later.txt"
  commit "$UP" g5
  git -C "$UP" -c core.hooksPath=/dev/null merge -q --no-ff --no-edit triage
  clone_global
  [ ! -e "$GM/candidates" ]
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' "outbox/$D1-first.md:carried: 同じ内容のファイルが Global Memory の履歴に在る: candidates/$D1-first.md" "outbox/$D2-second.md:carried: 同じ内容のファイルが Global Memory の履歴に在る: candidates/$D2-second.md")" ]
  [ ! -e "$GM/candidates" ]
}

@test "carry: 言い回しを直して records へ採った候補の下書きも、運んだときの内容が履歴に在るので carried" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  mkdir -p "$UP/candidates"
  cp "$PUP/docs/memory/outbox/$D1-first.md" "$UP/candidates/"
  commit "$UP" g1
  git -C "$UP" mv "candidates/$D1-first.md" "records/$D1-first.md"
  printf '\n%s\n' '言い回しを直した。' >>"$UP/records/$D1-first.md"
  commit "$UP" g2
  clone_global
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:carried: 同じ内容のファイルが Global Memory の履歴に在る: candidates/$D1-first.md" ]
}

@test "carry: 同じ識別子で内容の違うファイルが Global の履歴に在ると、写さずに stopped で exit 1 とし、ほかの下書きは写す" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  draft_in "$PUP/docs/memory" "$D2" second
  draft_in "$PUP/docs/memory" "$D3" third
  commit "$PUP" p1
  clone_project
  # D1: 別のプロジェクトが同じ識別子の記録を送り、records に在る（名前も違う）。
  record "$UP" "$D1" other-project
  # D3: 同じファイル名で内容の違う候補が、かつて在った（承認の後に書き換えた下書き）。
  mkdir -p "$UP/candidates"
  draft_in "$BATS_TEST_TMPDIR/rewritten" "$D3" third '書き換える前の本文。'
  cp "$BATS_TEST_TMPDIR/rewritten/outbox/$D3-third.md" "$UP/candidates/"
  commit "$UP" g1
  git -C "$UP" rm -q "candidates/$D3-third.md"
  commit "$UP" g2
  clone_global
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "outbox/$D1-first.md:stopped: 同じ識別子で内容の違うファイルが Global Memory の履歴に在る: records/$D1-other-project.md。別のプロジェクトの記録と識別子が重なったか、承認の後に下書きを書き換えた。人間が決める" ]
  [ "${lines[1]}" = "outbox/$D2-second.md:copied: candidates/$D2-second.md へ写した" ]
  [[ "${lines[2]}" == "outbox/$D3-third.md:stopped: 同じ識別子で内容の違うファイルが Global Memory の履歴に在る: candidates/$D3-third.md。"* ]]
  [ "${#lines[@]}" -eq 3 ]
  [ "$(ls -A "$GM/candidates")" = "$D2-second.md" ]
}

@test "carry: 下書きは Project の起点の木から読み、作業ツリーと作業中のブランチは読まない" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  # 作業中のブランチで、承認済みの下書きを書き換え、未承認の下書きを足す。作業ツリーにも未コミットの下書きを置く。
  git -C "$PJ" checkout -q -b topic
  printf '%s\n' '承認の後の書き換え。' >>"$PROOT/outbox/$D1-first.md"
  draft_in "$PROOT" "$D2" second
  commit "$PJ" topic
  draft_in "$PROOT" "$D3" third
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
  cmp "$PUP/docs/memory/outbox/$D1-first.md" "$GM/candidates/$D1-first.md"
  [ "$(ls -A "$GM/candidates")" = "$D1-first.md" ]
}

@test "carry: outbox が起点に無いと、何も出さずに exit 0" {
  init_project
  clone_project
  global_with_record
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
  [ ! -e "$GM/candidates" ]
}

@test "carry: ファイル名から識別子を読めない下書きは、写さずに stopped" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  mv "$PUP/docs/memory/outbox/$D1-first.md" "$PUP/docs/memory/outbox/Draft_One.md"
  commit "$PUP" p1
  clone_project
  global_with_record
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 1 ]
  [ "$output" = "outbox/Draft_One.md:stopped: ファイル名から識別子を読めない。<id>-<名前>.md の形にする" ]
  [ ! -e "$GM/candidates" ]
}

@test "carry: どちらかの履歴が浅いと、何も出さず何も書かずに exit 2 で止まり、取り直し方を示す" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  : >"$PUP/later.txt"
  commit "$PUP" p2
  clone_project --depth 1
  global_with_record
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch --deepen=1000 origin main"* ]]
  [[ "$stderr" == *"$PROOT"* ]]
  [ ! -e "$GM/candidates" ]
  git -C "$PJ" fetch -q --deepen=1000 origin main
  rm -rf "$GM"
  : >"$UP/later.txt"
  commit "$UP" g2
  clone_global --depth 1
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch --deepen=1000 origin main"* ]]
  [[ "$stderr" == *"$GM"* ]]
  [ ! -e "$GM/candidates" ]
  git -C "$GM" fetch -q --deepen=1000 origin main
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
}

@test "carry: 起点が最後に取り直した結果と食い違うと、リポジトリごとに照合して exit 2 で止まる" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  : >"$UP/later.txt"
  commit "$UP" g2
  git -C "$GM" fetch -q origin main
  # Project の remote 追跡の ref を、下書きを足す前へ戻す。
  git -C "$PJ" update-ref refs/remotes/origin/main "$(git -C "$PUP" rev-parse HEAD~1)"
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git fetch origin main"* ]]
  git -C "$PJ" update-ref refs/remotes/origin/main "$(git -C "$PUP" rev-parse HEAD)"
  rewind_tracking "$GM" HEAD~1
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ ! -e "$GM/candidates" ]
  # 取り直した直後の FETCH_HEAD を、それぞれの起点に渡せば通る。引数の順は問わない。
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --global-ref FETCH_HEAD --project-ref FETCH_HEAD
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
}

@test "carry: Project の起点が既定のブランチでないと、読まずに exit 2 で止まる（ローカルの枝・HEAD・タグ・コミット・ほかの枝）" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  git -C "$PUP" checkout -q -b other
  draft_in "$PUP/docs/memory" "$D2" second
  commit "$PUP" p2
  git -C "$PUP" checkout -q main
  clone_project
  global_with_record
  # 作業中のブランチに、未承認の下書きをコミットする。
  git -C "$PJ" checkout -q -b topic
  draft_in "$PROOT" "$D3" third
  commit "$PJ" topic
  git -C "$PJ" tag v1
  local ref
  for ref in main topic HEAD v1 main~0 "$(git -C "$PJ" rev-parse HEAD)" "$(git -C "$PJ" rev-parse --short origin/main)" \
    origin/other refs/remotes/origin/other; do
    run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --project-ref "$ref"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"既定のブランチ（origin の main）からしか読まない"* ]]
  done
  [ ! -e "$GM/candidates" ]
}

@test "carry: FETCH_HEAD は、origin の既定のブランチだけを取り直したときに限り、Project の起点に通す" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  git -C "$PUP" checkout -q -b other
  draft_in "$PUP/docs/memory" "$D2" second
  commit "$PUP" p2
  git -C "$PUP" checkout -q main
  clone_project
  global_with_record
  git -C "$PJ" fetch -q origin other
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --project-ref FETCH_HEAD
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"既定のブランチ（origin の main）からしか読まない"* ]]
  # 同じ名前の枝を、origin でない URL から取り直した FETCH_HEAD も通さない。
  git clone -q --bare "file://$PUP" "$BATS_TEST_TMPDIR/mirror.git"
  git -C "$BATS_TEST_TMPDIR/mirror.git" update-ref refs/heads/main "$(git -C "$PUP" rev-parse other)"
  git -C "$PJ" fetch -q "file://$BATS_TEST_TMPDIR/mirror.git" main
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --project-ref FETCH_HEAD
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"既定のブランチ（origin の main）からしか読まない"* ]]
  [ ! -e "$GM/candidates" ]
  git -C "$PJ" fetch -q origin main
  local ref
  for ref in FETCH_HEAD origin/main refs/remotes/origin/main origin/HEAD; do
    rm -rf "$GM/candidates"
    run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --project-ref "$ref"
    [ "$status" -eq 0 ]
    [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
  done
}

@test "carry: refs/remotes/origin/HEAD が無いか枝を指さないと、既定のブランチを決められず exit 2 で止まり、set-head を案内する" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  git -C "$PJ" remote set-head origin -d
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM" --project-ref FETCH_HEAD
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git remote set-head origin"* ]]
  git -C "$PJ" update-ref --no-deref refs/remotes/origin/HEAD "$(git -C "$PJ" rev-parse origin/main)"
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"git remote set-head origin"* ]]
  [ ! -e "$GM/candidates" ]
  git -C "$PJ" update-ref -d refs/remotes/origin/HEAD
  git -C "$PJ" remote set-head origin main
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
}

@test "carry: Global の作業ツリーの candidates がディレクトリでないと、何も出さずに exit 2" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  : >"$GM/candidates"
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"candidates がディレクトリでない"* ]]
}

@test "carry: 記憶の根でない引数と、形に合わない引数は exit 2 で終わる" {
  init_project
  clone_project
  global_with_record
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run --separate-stderr node "$SUT" carry "$PROOT" "$BATS_TEST_TMPDIR/plain"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  local args
  for args in "$PROOT" "$PROOT $GM extra" "$PROOT $GM --ref main" "$PROOT $GM --project-ref" \
    "$PROOT $GM --project-ref main --project-ref main" "$PROOT $GM --global-ref -main" \
    "$PROOT $GM --project-ref=main" "--project-ref main $PROOT $GM"; do
    # shellcheck disable=SC2086
    run --separate-stderr node "$SUT" carry $args
    [ "$status" -eq 2 ]
    [ -z "$output" ]
  done
  run --separate-stderr node "$SUT" version "$PROOT" "$A" --project-ref main
  [ "$status" -eq 2 ]
}

@test "carry: 継承した GIT_DIR に左右されず、渡した2つの根のリポジトリを読む" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  global_with_record
  run --separate-stderr env "GIT_DIR=$PUP/.git" node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:copied: candidates/$D1-first.md へ写した" ]
}

@test "carry: マージのコミットで初めて出来た内容も、履歴に在るものとして carried" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  clone_project
  record "$UP" "$A" first
  commit "$UP" g1
  git -C "$UP" checkout -q -b side
  : >"$UP/side.txt"
  commit "$UP" g2
  git -C "$UP" checkout -q main
  : >"$UP/main.txt"
  commit "$UP" g3
  # 下書きの内容は、マージを解決するときにだけ足し、起点まで残す。マージでない差分には、一度も現れない。
  git -C "$UP" -c core.hooksPath=/dev/null merge -q --no-ff --no-commit side
  mkdir -p "$UP/candidates"
  cp "$PUP/docs/memory/outbox/$D1-first.md" "$UP/candidates/"
  commit "$UP" merge
  : >"$UP/later.txt"
  commit "$UP" g4
  clone_global
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 0 ]
  [ "$output" = "outbox/$D1-first.md:carried: 同じ内容のファイルが Global Memory の履歴に在る: candidates/$D1-first.md" ]
}

@test "carry: Project の remote が origin でないと exit 2 で止まり、何も書かず、origin への改名を示す" {
  init_project
  draft_in "$PUP/docs/memory" "$D1" first
  commit "$PUP" p1
  git clone -q -o upstream "file://$PUP" "$PJ"
  git -C "$PJ" fetch -q upstream main
  global_with_record
  run --separate-stderr node "$SUT" carry "$PROOT" "$GM"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"origin"* ]]
  [[ "$stderr" == *"rename"* ]]
  [ ! -e "$GM/candidates" ] || [ -z "$(ls -A "$GM/candidates")" ]
}
