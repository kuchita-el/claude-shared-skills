#!/usr/bin/env bats
load 'helpers/common'

# 上限の解決は CLAUDE_PROJECT_DIR のプロファイルを読む。実行環境の値に判定を左右されないよう、
# 各試験の既定では外し、プロファイルを使う試験だけが明示的に設定する。
setup() {
  unset CLAUDE_PROJECT_DIR
}

@test "一文長違反はexit 1で場所と規則を報告する" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$REPO_ROOT/scripts/fixtures/writing/lint/invalid/long-line.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長:"* ]]
}

@test "上限以内の文書は通過する" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/grounded-terms.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# 試験用の git リポジトリを $BATS_TEST_TMPDIR/$1 に作る。commit_repo はその時点の中身を基点として commit する。
make_repo() {
  repo="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
}
commit_repo() {
  git -C "$repo" add -A && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
}
# $repo を作業ディレクトリにして lint-ja.mjs を走らせる。引数はそのまま lint-ja.mjs へ渡す。
lint_in_repo() {
  run bash -c 'cd "$1" && shift && node "$@"' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" "$@"
}

@test "diffモードは指定したパスの変更だけを検査し、指定しないパスの変更を検査しない" {
  make_repo two-paths
  printf '%s\n' '短い。' > "$repo/a.md"
  printf '%s\n' '短い。' > "$repo/b.md"
  commit_repo
  printf '%s。\n' "$(printf 'あ%.0s' {1..120})" > "$repo/a.md"
  printf '%s。\n' "$(printf 'い%.0s' {1..120})" > "$repo/b.md"
  lint_in_repo --diff HEAD -- a.md
  [ "$status" -eq 1 ]
  [[ "$output" == *'a.md:1:一文長: 121字'* ]]
  [[ "$output" != *'b.md'* ]]
}

@test "fileとdiffの同時指定や不正引数を拒否する" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file foo --diff HEAD -- foo
  [ "$status" -eq 2 ]
}

# 識別子と参照の説明は lint の検査に含めない。独立レビューが判定する。
@test "ADRの識別子とIssue番号を含む文書でも、file・diffのどちらでも候補を報告しない" {
  make_repo identifiers
  touch "$repo/.keep"
  commit_repo
  printf '%s\n' 'ADR-202601010000-01 と #683 の決定に従う。' 'Issue #684 を見る。' > "$repo/ids.md"
  lint_in_repo --file ids.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_in_repo --diff HEAD -- ids.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "プロジェクトprofileの一文長上限を使う" {
  mkdir -p "$BATS_TEST_TMPDIR/project/.claude/writing"
  printf '%s\n' '# profile' '| 種別 | 節構成 | 読み手 | 一文長の上限 |' '|---|---|---|---|' '| 汎用 | 定めない | 一般読者 | 50 |' > "$BATS_TEST_TMPDIR/project/.claude/writing/type-profiles.md"
  printf '%s\n' 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお。' > "$BATS_TEST_TMPDIR/profile.md"
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/project" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/profile.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"上限50"* ]]
}

@test "diffモードは既存の未編集違反を検査しない" {
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  # 1行目は未編集のまま残す既存の違反（121字）。--file で検査すれば違反になることを先に押さえる。
  existing="$(printf 'あ%.0s' {1..120})。"
  printf '%s\n%s\n' "$existing" '変更前。' > "$repo/doc.md"
  git -C "$repo" add doc.md && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
  run bash -c 'cd "$1" && node "$2" --file doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 1 ]
  [[ "$output" == *'doc.md:1:一文長: 121字'* ]]
  sed -i 's/変更前。/変更後。/' "$repo/doc.md"
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s\n%s。\n' "$existing" "$(printf 'う%.0s' {1..120})" > "$repo/doc.md"
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 1 ]
  [[ "$output" == *'doc.md:2:一文長: 121字'* ]]
  [[ "$output" != *'doc.md:1:'* ]]
}

@test "diffモードは未追跡の新規文書を検査する" {
  repo="$BATS_TEST_TMPDIR/untracked-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  touch "$repo/.keep"
  git -C "$repo" add .keep && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
  printf '%s。\n' "$(printf 'あ%.0s' {1..120})" > "$repo/new.md"
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- new.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 1 ]
}

# ハンク見出しの文脈部（git が変更箇所の手前の英字始まりの行を入れる）に + があっても、
# 変更行の開始行を見出しの新側の開始行から読めることを押さえる（#941）。
# 引数: 作業名と1行目の文言。3行目は未変更の長文（121字）で、変更は8行目の周辺に入れる。
make_hunk_context_repo() {
  repo="$BATS_TEST_TMPDIR/$1"
  long="$(printf 'う%.0s' {1..120})。"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  {
    printf '%s\n' "$2" '短い。' "$long"
    printf '短い%s。\n' 4 5 6 7 8 9 10 11
  } > "$repo/a.md"
  git -C "$repo" add a.md && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
}

run_lint_diff() {
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- a.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
}

@test "diffモードは見出しの文脈に+があっても変更行だけを検査する" {
  make_hunk_context_repo plus-context 'N+3 の手順を述べる。'
  sed -i "8s/.*/$long/" "$repo/a.md"
  git -C "$repo" diff --unified=0 a.md | grep -F '@@ -8 +8 @@ N+3'
  run_lint_diff
  [ "$status" -eq 1 ]
  [[ "$output" == *'a.md:8:一文長: 121字'* ]]
  [[ "$output" != *'a.md:3:'* ]]
}

@test "diffモードは追加のみの見出しでも文脈の+に左右されない" {
  make_hunk_context_repo plus-context-add 'N+3 の手順を述べる。'
  { head -n 8 "$repo/a.md"; printf '%s\n' "$long" "$long"; tail -n +9 "$repo/a.md"; } > "$repo/b.md"
  mv "$repo/b.md" "$repo/a.md"
  git -C "$repo" diff --unified=0 a.md | grep -F '@@ -8,0 +9,2 @@ N+3'
  run_lint_diff
  [ "$status" -eq 1 ]
  [[ "$output" == *'a.md:9:一文長'* ]]
  [[ "$output" == *'a.md:10:一文長'* ]]
  [[ "$output" != *'a.md:3:'* ]]
}

@test "diffモードは見出しの文脈に+が無い場合も変更行だけを検査する" {
  make_hunk_context_repo no-plus-context 'Nの手順を述べる。'
  sed -i "8s/.*/$long/" "$repo/a.md"
  git -C "$repo" diff --unified=0 a.md | grep -F '@@ -8 +8 @@ N'
  run_lint_diff
  [ "$status" -eq 1 ]
  [[ "$output" == *'a.md:8:一文長: 121字'* ]]
  [[ "$output" != *'a.md:3:'* ]]
}

@test "lintは文単位で数え、改行をまたぐ一文も検出する" {
  first=$(printf 'あ%.0s' {1..60})
  second=$(printf 'い%.0s' {1..60})
  printf '%s。%s。\n' "$first" "$second" > "$BATS_TEST_TMPDIR/two-sentences.md"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/two-sentences.md"
  [ "$status" -eq 0 ]
  printf '%s\n%s。\n' "$(printf 'あ%.0s' {1..80})" "$(printf 'い%.0s' {1..40})" > "$BATS_TEST_TMPDIR/wrapped-sentence.md"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/wrapped-sentence.md"
  [ "$status" -eq 1 ]
}

# 一文長の検査が Markdown の構造（表・箇条書き・見出し・コードブロック）を地の文と見分けることの試験。
# rep は文字 $1 を $2 回並べる。lint_tmp は残りの引数を1行ずつ書いた文書へ --file を掛ける。
rep() { local s='' k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }
lint_tmp() {
  printf '%s\n' "${@:2}" > "$BATS_TEST_TMPDIR/$1"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/$1"
}

@test "表だけの文書は一文長を報告しない" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/table-only.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "表の直前で文が終端し、表の前後の散文を1文につながない" {
  lint_tmp around-table.md "$(rep あ 60)" '| 列 | 値 |' '|---|---|' '| 一 | 二 |' "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "表の直前の散文の長文は表で区切っても報告する" {
  lint_tmp long-before-table.md "$(rep あ 60)" "$(rep い 50)。" '| 列 | 値 |' '|---|---|'
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 111字"* ]]
}

@test "コードブロック内の|で始まる行を表と誤認せず、閉じのフェンスの後の長文を報告する" {
  lint_tmp pipe-in-code.md '```' '| 列 | 値 |' '|---|---|' '```' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":5:一文長: 102字"* ]]
}

@test "表の行の中のフェンス記号でコードブロックを始めない" {
  lint_tmp fence-in-table.md '| 記号 | ``` |' '|---|---|' '' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":4:一文長: 102字"* ]]
}

@test "句点の無い箇条書きの項目をつながない" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/unpunctuated-list.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "記号と番号の異なる箇条書きの項目の始まりでも区切る" {
  lint_tmp markers.md "* $(rep あ 40)" "+ $(rep い 40)" "1. $(rep う 40)" "2) $(rep え 40)" "  - $(rep お 40)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "1つの箇条書きの項目の中で句点まで続く100字超の文は報告する" {
  lint_tmp long-item.md "- $(rep あ 30)" "- $(rep い 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":2:一文長: 104字"* ]]
}

@test "字下げした継続行は項目の途中で区切らず、項目の続きとして数える" {
  lint_tmp continued-item.md "- $(rep あ 60)" "  $(rep い 50)。" "- $(rep う 30)"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 115字"* ]]
  [[ "$output" != *":3:"* ]]
}

@test "見出しの行を前後の地の文とつながない" {
  lint_tmp heading.md "$(rep あ 60)" "## $(rep い 50)" "$(rep う 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "見出しの直後の長文と、見出しの行そのものの長文は報告する" {
  lint_tmp after-heading.md '## 見出し' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":2:一文長: 102字"* ]]
  lint_tmp long-heading.md "## $(rep あ 101)" '本文。'
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 104字"* ]]
}

@test "コードブロックの中身を地の文として数えない" {
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/code-block.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "コードブロックの前後の段落の101字の文は報告する" {
  lint_tmp long-before-code.md "$(rep あ 101)。" '' '```' 'echo ok' '```'
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 102字"* ]]
  lint_tmp long-after-code.md '```' 'echo ok' '```' '' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":5:一文長: 102字"* ]]
}

@test "空行を挟まないフェンスの前後で地の文にコードブロックの中身を足さない" {
  lint_tmp prose-then-fence.md "$(rep あ 60)" '```' "$(rep x 60)" '```'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp fence-then-prose.md '```' "$(rep x 60)" '```' "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "閉じのフェンスが無ければ文書の終わりまでをコードブロックとして扱う" {
  lint_tmp unclosed-fence.md '前置き。' '```' "$(rep x 60)" "$(rep x 60)" "$(rep あ 120)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "チルダのフェンスはバッククォートの行で閉じない" {
  lint_tmp tilde-fence.md '~~~markdown' '```' "$(rep あ 120)。" '```' '~~~'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "差分の方式でコードブロックの中の1行だけを変えても一文長を指摘しない" {
  repo="$BATS_TEST_TMPDIR/code-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  cp "$REPO_ROOT/scripts/fixtures/writing/lint/valid/code-block.md" "$repo/doc.md"
  git -C "$repo" add doc.md && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
  sed -i 's/入口の試験/入口の試験と注記/' "$repo/doc.md"
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# 構造の判定の境界の試験。構造と見なす範囲を広げすぎると、地の文の長文を見逃す。
# 以下は、境界の外の行が地の文のまま数えられ、長文として報告されることを押さえる。

@test "行の途中に|がある地の文は表と見ず、長文を報告する" {
  lint_tmp mid-pipe.md "$(rep あ 50) | $(rep い 50)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 104字"* ]]
}

@test "#の直後に空白の無い行は見出しと見ず、前の行とつないで報告する" {
  lint_tmp hash-number.md "$(rep あ 60)" "#417 は$(rep い 40)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 107字"* ]]
}

@test "記号の直後に空白の無い行は項目と見ず、前の行とつないで報告する" {
  lint_tmp emphasis.md "$(rep あ 60)" "*強調*$(rep い 40)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 105字"* ]]
  lint_tmp minus-number.md "$(rep あ 60)" "-1は$(rep い 40)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 104字"* ]]
}

@test "4つのバッククォートで開いたフェンスは、中の3つのバッククォートの行で閉じない" {
  lint_tmp long-fence.md '````markdown' '```' "$(rep あ 120)。" '```' '````'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "情報文字列の付いたフェンスの行ではコードブロックを閉じない" {
  lint_tmp info-not-close.md '```' '```bash' "$(rep あ 120)。" '```'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "字下げしたフェンスも、字下げの深さによらずコードブロックとして扱う" {
  lint_tmp indented-fence.md '- 項目' '    ```' "    $(rep あ 120)。" '    ```'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "箇条書きの中で字下げした表も表として数えない" {
  lint_tmp indented-table.md '- 項目' '' "    | $(rep あ 60) | $(rep い 60) |" '    |---|---|'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "改行がCRLFの文書でも閉じのフェンスと空行を認める" {
  printf '```\r\necho\r\n```\r\n\r\n%s。\r\n' "$(rep あ 101)" > "$BATS_TEST_TMPDIR/crlf-fence.md"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/crlf-fence.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":5:一文長: 102字"* ]]
  printf '%s\r\n\r\n%s。\r\n' "$(rep あ 60)" "$(rep い 60)" > "$BATS_TEST_TMPDIR/crlf-blank.md"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/crlf-blank.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "行頭のインラインコードではコードブロックを開かない" {
  lint_tmp inline-code.md '```foo``` を使う。' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":2:一文長: 102字"* ]]
}

# 差分の方式が、変更によって生じた文を行の中の位置によらず検査することの試験（#938）。
# 変更によって生じた文とは、変えた行の文字を含む文と、行の削除で前後がつながった文である。
# make_diff_repo は残りの引数を1行ずつ書いた doc.md をコミットする。run_doc_diff はその差分へ --diff を掛ける。
make_diff_repo() {
  repo="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  printf '%s\n' "${@:2}" > "$repo/doc.md"
  git -C "$repo" add doc.md && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
}
run_doc_diff() {
  run bash -c 'cd "$1" && node "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
}

@test "差分の方式は、変えた行の2文目の長文を報告する" {
  make_diff_repo mid-line '変更前。'
  printf '短い文。%s。\n' "$(rep う 120)" > "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = 'doc.md:1:一文長: 121字（上限100）' ]
}

@test "差分の方式は、変えた行の途中から始まり変えていない次の行へ続く長文を報告する" {
  make_diff_repo mid-line-cont '前の文。' "$(rep え 60)。"
  sed -i "1s/.*/前の文。$(rep お 60)/" "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = 'doc.md:1:一文長: 121字（上限100）' ]
}

@test "差分の方式は、行の削除で前後がつながった長文を報告する" {
  make_diff_repo joined "$(rep あ 60)" '' "$(rep い 60)。"
  sed -i '2d' "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = 'doc.md:1:一文長: 121字（上限100）' ]
}

@test "差分の方式は、削除でつながった文が閉じた後に続く既存の長文を報告しない" {
  # つながった文の印が、その文の終端で外れることを確かめる。後ろの長文は同じ行・次の行のどちらでも既存のまま。
  make_diff_repo joined-then-existing "$(rep あ 60)" '' "$(rep い 60)。$(rep う 120)。" "$(rep え 120)。"
  sed -i '2d' "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = 'doc.md:1:一文長: 121字（上限100）' ]
}

@test "差分の方式は、変えていない行の途中から始まる既存の長文を報告しない" {
  make_diff_repo unchanged-mid-line "短い文。$(rep う 120)。" '変更前。'
  sed -i 's/変更前。/変更後。/' "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "差分の方式は、前後を文としてつながない行の削除では既存の長文を報告しない" {
  # 削除した行の直前で文が終端しているので、削除で文はつながらない。後ろの長文は既存のまま。
  make_diff_repo deleted-no-join '前の文。' '消す文。' "$(rep い 120)。"
  sed -i '2d' "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # 段落の間の空行を消しても、前の段落が句点で閉じていれば後ろの既存の長文は報告しない。
  make_diff_repo deleted-blank-no-join '前の文。' '' "$(rep い 120)。"
  sed -i '2d' "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# 文書種別ごとの一文長の上限（--type）の試験。
# write_profile は残りの引数を行として、プロジェクト固有のプロファイルを表の見出しの後に書く。
# lint_project は、そのプロファイルを持つプロジェクトの下で lint-ja.mjs を走らせる。
write_profile() {
  mkdir -p "$BATS_TEST_TMPDIR/project/.claude/writing"
  printf '%s\n' '# profile' '| 種別 | 節構成 | 読み手 | 一文長の上限 |' '|---|---|---|---|' "$@" > "$BATS_TEST_TMPDIR/project/.claude/writing/type-profiles.md"
}
lint_project() {
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/project" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" "$@"
}

@test "--typeで指定した種別の行の上限を、プロジェクト固有のプロファイルから採る" {
  write_profile '| 汎用 | 定めない | 一般読者 | 50字 |' '| 報告書 | 定めない | 一般読者 | 70字 |'
  printf '%s。\n' "$(rep あ 59)" > "$BATS_TEST_TMPDIR/sixty.md"
  lint_project --type 報告書 --file "$BATS_TEST_TMPDIR/sixty.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s。\n' "$(rep あ 70)" > "$BATS_TEST_TMPDIR/seventy-one.md"
  lint_project --type 報告書 --file "$BATS_TEST_TMPDIR/seventy-one.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 71字（上限70）"* ]]
}

@test "上限の欄の「字」の有無は、ロケールによらず読める" {
  # 欄の読み取りは字の数え方と無関係なので、UTF-8 以外のロケールでも「字」の無い数値を読める。
  write_profile '| 汎用 | 定めない | 一般読者 | 70 |' '| 報告書 | 定めない | 一般読者 | 70字 |'
  printf 'short.\n' > "$BATS_TEST_TMPDIR/short.md"
  for type in 汎用 報告書; do
    run env LC_ALL=C CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/project" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --type "$type" --file "$BATS_TEST_TMPDIR/short.md"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "--typeを省略したときは汎用の行の上限を採る" {
  write_profile '| 汎用 | 定めない | 一般読者 | 50字 |' '| 報告書 | 定めない | 一般読者 | 70字 |'
  printf '%s。\n' "$(rep あ 59)" > "$BATS_TEST_TMPDIR/sixty.md"
  lint_project --file "$BATS_TEST_TMPDIR/sixty.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 60字（上限50）"* ]]
}

@test "プロジェクト固有のプロファイルに行の無い種別は、同梱の既定の汎用の上限を採る" {
  write_profile '| 汎用 | 定めない | 一般読者 | 50字 |' '| 報告書 | 定めない | 一般読者 | 70字 |'
  printf '%s。\n' "$(rep あ 99)" > "$BATS_TEST_TMPDIR/hundred.md"
  lint_project --type 議事録 --file "$BATS_TEST_TMPDIR/hundred.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s。\n' "$(rep あ 100)" > "$BATS_TEST_TMPDIR/hundred-one.md"
  lint_project --type 議事録 --file "$BATS_TEST_TMPDIR/hundred-one.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字（上限100）"* ]]
}

@test "同梱の既定の上限は、lint-ja.mjsと同じプラグインのdocument-type-profiles.mdの汎用の行から読む" {
  plugin="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$plugin/scripts" "$plugin/references"
  cp -R "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" "$REPO_ROOT/plugins/writing/scripts/vendor" "$plugin/scripts/"
  sed 's/| 100字 |$/| 80字 |/' "$REPO_ROOT/plugins/writing/references/document-type-profiles.md" > "$plugin/references/document-type-profiles.md"
  grep -F '| 80字 |' "$plugin/references/document-type-profiles.md"
  printf '%s。\n' "$(rep あ 80)" > "$BATS_TEST_TMPDIR/eighty-one.md"
  run env -u CLAUDE_PROJECT_DIR node "$plugin/scripts/lint-ja.mjs" --type 議事録 --file "$BATS_TEST_TMPDIR/eighty-one.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 81字（上限80）"* ]]
  rm "$plugin/references/document-type-profiles.md"
  run env -u CLAUDE_PROJECT_DIR node "$plugin/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/eighty-one.md"
  [ "$status" -eq 0 ]
}

@test "種別名は表の先頭の列と一致する行だけを引き、他の列に同じ語があっても採らない" {
  write_profile '| 汎用 | 報告書に準じる | 一般読者 | 50字 |'
  printf '%s。\n' "$(rep あ 59)" > "$BATS_TEST_TMPDIR/sixty.md"
  lint_project --type 報告書 --file "$BATS_TEST_TMPDIR/sixty.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "diffモードでも--typeの上限を適用する" {
  write_profile '| 報告書 | 定めない | 一般読者 | 70字 |'
  make_repo typed-diff
  touch "$repo/.keep"
  commit_repo
  printf '%s。\n' "$(rep あ 70)" > "$repo/new.md"
  run bash -c 'cd "$1" && CLAUDE_PROJECT_DIR="$2" node "$3" --type 報告書 --diff HEAD -- new.md' _ "$repo" "$BATS_TEST_TMPDIR/project" "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  [ "$status" -eq 1 ]
  [[ "$output" == *"new.md:1:一文長: 71字（上限70）"* ]]
}

@test "--typeの値が無い・空・重複のときは引数の誤りとして拒否する" {
  printf '%s\n' '短い。' > "$BATS_TEST_TMPDIR/short.md"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/short.md" --type
  [ "$status" -eq 2 ]
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --type '' --file "$BATS_TEST_TMPDIR/short.md"
  [ "$status" -eq 2 ]
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --type 汎用 --type 報告書 --file "$BATS_TEST_TMPDIR/short.md"
  [ "$status" -eq 2 ]
}

# 検査の前提が成り立たない経路は、違反の有無（0・1）と区別して終了コード 2 と理由を返す。

@test "diffモードに存在しないパスを渡すと、終了コード2と理由を返す" {
  make_repo missing-path
  printf '%s\n' '短い。' > "$repo/a.md"
  commit_repo
  lint_in_repo --diff HEAD -- a.md missing.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing.md"* && "$output" == *"無い"* ]]
}

@test "Markdown以外のファイルを渡すと、file・diffのどちらでも終了コード2と理由を返す" {
  make_repo not-markdown
  printf '%s\n' '短い。' > "$repo/notes.txt"
  commit_repo
  lint_in_repo --file notes.txt
  [ "$status" -eq 2 ]
  [[ "$output" == *"notes.txt"* && "$output" == *"Markdown"* ]]
  lint_in_repo --diff HEAD -- notes.txt
  [ "$status" -eq 2 ]
  [[ "$output" == *"notes.txt"* && "$output" == *"Markdown"* ]]
}

@test "拡張子が.markdownのファイルはMarkdownとして検査する" {
  printf '%s。\n' "$(rep あ 101)" > "$BATS_TEST_TMPDIR/long.markdown"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/long.markdown"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 102字"* ]]
}

@test "該当する種別の行の上限を数値として読めないと、終了コード2と理由を返す" {
  write_profile '| 汎用 | 定めない | 一般読者 | 定めない |' '| 報告書 | 定めない | 一般読者 | 七十字 |'
  printf '%s\n' '短い。' > "$BATS_TEST_TMPDIR/short.md"
  lint_project --type 報告書 --file "$BATS_TEST_TMPDIR/short.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"報告書"* && "$output" == *"上限"* ]]
  lint_project --file "$BATS_TEST_TMPDIR/short.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"汎用"* && "$output" == *"上限"* ]]
}

@test "diffモードの基点がcommitを指さないと、終了コード2と理由を返す" {
  make_repo tree-base
  printf '%s\n' '短い。' > "$repo/a.md"
  commit_repo
  tree=$(git -C "$repo" rev-parse 'HEAD^{tree}')
  lint_in_repo --diff "$tree" -- a.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"$tree"* && "$output" == *"commit"* ]]
  lint_in_repo --diff no-such-ref -- a.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"no-such-ref"* && "$output" == *"commit"* ]]
}

# 一文の長さの計数規則（references/japanese-writing.md 第5条の補則）の各項目を、規則どおりに数えることの試験。
# 項目 (e) のうち表・見出し・箇条書き・コードブロックは、上の Markdown の構造の試験が受け持つ。

@test "計数(a): 全角と半角をどちらも1字と数え、上限ちょうどは通す" {
  lint_tmp mixed-100.md "$(rep a 49)$(rep あ 50)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp mixed-101.md "$(rep a 50)$(rep あ 50)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字（上限100）"* ]]
}

@test "計数(b): コードスパンはバッククォートと内部の字をそのまま数える" {
  lint_tmp code-span.md "\`$(rep x 48)\`$(rep あ 51)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 102字"* ]]
}

@test "計数(c): 。！？!? のそれぞれで文を区切り、. と、では区切らない" {
  for mark in '。' '！' '？' '!' '?'; do
    lint_tmp mark.md "$(rep あ 60)${mark}$(rep い 60)${mark}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  lint_tmp period.md "$(rep あ 60).$(rep い 60)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 122字"* ]]
  lint_tmp comma.md "$(rep あ 60)、$(rep い 60)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 122字"* ]]
}

@test "計数(d): 括弧の内側の区切り記号でも文を区切る" {
  lint_tmp bracket.md "（$(rep あ 60)。$(rep い 60)）。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp bracket-long.md "（$(rep あ 60)。$(rep い 99)）。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字"* ]]
}

@test "計数(e): 地の文の改行では区切らず改行を数えない。空行では区切る" {
  lint_tmp wrapped-100.md "$(rep あ 50)" "$(rep い 49)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp wrapped-101.md "$(rep あ 50)" "$(rep い 50)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字"* ]]
  lint_tmp blank-split.md "$(rep あ 60)" '' "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "計数(e): 空白とタブだけの行も空行として文を区切る" {
  lint_tmp spaces-split.md "$(rep あ 60)" '   ' "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp tab-split.md "$(rep あ 60)" "$(printf ' \t ')" "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # 空白だけの行の空白は、直前の文の字に数えない（直前の文は99字）。
  lint_tmp spaces-not-counted.md "$(rep あ 99)" '   ' 'い。'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "計数(a): コードポイント単位で数え、分解形の濁点を別の1字に数える" {
  lint_tmp nfd.md "$(rep "$(printf 'か\xe3\x82\x99')" 50)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字"* ]]
}

@test "計数(e): 字下げだけのコードブロックはコードブロックと見ず、地の文として数える" {
  lint_tmp indented-code.md '前置き。' '' "    $(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":3:一文長: 106字"* ]]
}

@test "計数(a): 文の先頭の字下げも字に含める" {
  lint_tmp indent-100.md "  $(rep あ 97)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp indent-101.md "  $(rep あ 98)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字"* ]]
}

@test "プロジェクト固有のプロファイルが無いときは、同梱の汎用の上限を採り、検査できない扱いにしない" {
  mkdir -p "$BATS_TEST_TMPDIR/empty-project"
  printf '%s。\n' "$(rep あ 99)" > "$BATS_TEST_TMPDIR/hundred.md"
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/empty-project" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --type 報告書 --file "$BATS_TEST_TMPDIR/hundred.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s。\n' "$(rep あ 100)" > "$BATS_TEST_TMPDIR/hundred-one.md"
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/empty-project" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --type 報告書 --file "$BATS_TEST_TMPDIR/hundred-one.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字（上限100）"* ]]
}

@test "拡張子の大文字小文字を問わずMarkdownとして検査する" {
  printf '%s。\n' "$(rep あ 101)" > "$BATS_TEST_TMPDIR/UP.MD"
  run node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/UP.MD"
  [ "$status" -eq 1 ]
  [[ "$output" == *"UP.MD:1:一文長: 102字"* ]]
}

# 作り直しの前後で保つ振る舞いを固定する試験（#959）。

@test "差分の方式は、変えていない行で始まり変えた行で終わる長文を報告する" {
  make_diff_repo head-unchanged "$(rep あ 60)" "$(rep い 40)。"
  printf '%s\n%s。\n' "$(rep あ 60)" "$(rep う 40)" > "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = "doc.md:1:一文長: 101字（上限100）" ]
}

@test "プロジェクト固有のプロファイルも同梱の既定も読めないときは、上限100を採る" {
  plugin="$BATS_TEST_TMPDIR/bare-plugin"
  mkdir -p "$plugin/scripts"
  cp -R "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" "$REPO_ROOT/plugins/writing/scripts/vendor" "$plugin/scripts/"
  printf '%s。\n' "$(rep あ 99)" > "$BATS_TEST_TMPDIR/bare-100.md"
  run env -u CLAUDE_PROJECT_DIR node "$plugin/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/bare-100.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s。\n' "$(rep あ 100)" > "$BATS_TEST_TMPDIR/bare-101.md"
  run env -u CLAUDE_PROJECT_DIR node "$plugin/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/bare-101.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 101字（上限100）"* ]]
}

@test "引数の誤りを終了コード2で拒む" {
  printf '短い文。\n' > "$BATS_TEST_TMPDIR/args.md"
  local lint="$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs"
  run node "$lint" --bogus --file "$BATS_TEST_TMPDIR/args.md"
  [ "$status" -eq 2 ]
  run node "$lint" --file "$BATS_TEST_TMPDIR/args.md" --
  [ "$status" -eq 2 ]
  run node "$lint" --diff HEAD
  [ "$status" -eq 2 ]
  run node "$lint" --diff HEAD --
  [ "$status" -eq 2 ]
  run node "$lint"
  [ "$status" -eq 2 ]
}

# 構造を CommonMark と GFM の表の定義で読み、字をロケールによらずコードポイントで数えることの試験（#959）。

@test "ロケールによらず同じ結果を返す" {
  f="$BATS_TEST_TMPDIR/locale.md"
  printf '%s\n' "$(rep あ 99)。" "$(rep い 100)！" "$(rep "$(printf 'か\xe3\x82\x99')" 50)？" '' \
    '| 列 | 値 |' '|---|---|' "| $(rep う 120) | 値 |" '' '```' "$(rep え 120)" '```' > "$f"
  expected="$f:2:一文長: 101字（上限100）"$'\n'"$f:3:一文長: 101字（上限100）"
  for locale in C C.UTF-8; do
    run env LC_ALL="$locale" node "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" --file "$f"
    [ "$status" -eq 1 ]
    [ "$output" = "$expected" ]
  done
}

@test "front-matter を地の文としてつながない" {
  lint_tmp front-matter.md '---' "title: $(rep x 120)" "description: $(rep y 120)" '---' "$(rep あ 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  lint_tmp front-matter-short.md '---' 'title: x' '---' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":4:一文長: 102字"* ]]
}

@test "閉じの無い --- は front-matter と見ず、後ろの長文を報告する" {
  lint_tmp unclosed-front-matter.md '---' '' "$(rep あ 120)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":3:一文長: 121字"* ]]
}

@test "区切りの行の無い | 始まりの行は表と見ず、地の文として数える" {
  lint_tmp pipe-without-delimiter.md "| $(rep あ 60)" "$(rep い 50)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長: 113字"* ]]
}

@test "1行の中で始まる文は、その文の始まりの行で報告する" {
  lint_tmp mid-line-start.md "$(rep あ 60)" "$(rep い 60)。$(rep う 120)。"
  [ "$status" -eq 1 ]
  f="$BATS_TEST_TMPDIR/mid-line-start.md"
  [ "$output" = "$f:1:一文長: 121字（上限100）"$'\n'"$f:2:一文長: 121字（上限100）" ]
}

@test "差分の方式は、++ で始まる追加行の後ろの変えた長文を報告する" {
  make_diff_repo plus-plus-line '前。' '後。'
  printf '%s\n' '前。' '++ 足した行。' "$(rep あ 120)。" '後。' > "$repo/doc.md"
  run_doc_diff
  [ "$status" -eq 1 ]
  [ "$output" = 'doc.md:3:一文長: 121字（上限100）' ]
}

@test "同梱の解析器を読み込めないとき、終了コード2と理由を返す" {
  # 解析器（vendor/）を写さない偽のプラグインで起動する。未捕捉の例外の終了コード 1 を返さないことを押さえる。
  plugin="$BATS_TEST_TMPDIR/no-parser-plugin"
  mkdir -p "$plugin/scripts"
  cp "$REPO_ROOT/plugins/writing/scripts/lint-ja.mjs" "$plugin/scripts/"
  printf '短い文。\n' > "$BATS_TEST_TMPDIR/no-parser.md"
  run node "$plugin/scripts/lint-ja.mjs" --file "$BATS_TEST_TMPDIR/no-parser.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"markdown-it"* ]]
}
