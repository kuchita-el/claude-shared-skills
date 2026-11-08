#!/usr/bin/env bats
load 'helpers/common'

@test "説明なしIssue番号を候補として報告する" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/invalid/unresolved-id.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"説明のない不透明な識別子"* ]]
}

@test "一文長違反はexit 1で場所と規則を報告する" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/invalid/long-line.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":1:一文長:"* ]]
}

@test "上限以内の文書は通過する" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/grounded-terms.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "候補だけでは終了コードを失敗にしない" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/candidate/unresolved-id.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"説明のない不透明な識別子"* ]]
}

@test "diffモードは指定パスの変更内容だけを検査する" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --diff HEAD -- scripts/fixtures/writing/lint/valid/grounded-terms.md
  [ "$status" -eq 0 ]
}

@test "fileとdiffの同時指定や不正引数を拒否する" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file foo --diff HEAD -- foo
  [ "$status" -eq 2 ]
}

@test "退役ADRの差分は適用限界として対象外にする" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --diff HEAD -- scripts/fixtures/writing/lint/retired-adr.diff
  [ "$status" -eq 0 ]
}

@test "プロジェクトprofileの一文長上限を使う" {
  mkdir -p "$BATS_TEST_TMPDIR/project/.claude/writing"
  printf '%s\n' '# profile' '| 種別 | 節構成 | 読み手 | 一文長の上限 |' '|---|---|---|---|' '| 汎用 | 定めない | 一般読者 | 50 |' > "$BATS_TEST_TMPDIR/project/.claude/writing/type-profiles.md"
  printf '%s\n' 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお。' > "$BATS_TEST_TMPDIR/profile.md"
  run env CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/project" bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/profile.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"上限50"* ]]
}

@test "diffモードは既存の未編集違反を検査しない" {
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  printf '%s\n%s\n' 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお。' '変更前。' > "$repo/doc.md"
  git -C "$repo" add doc.md && git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm base
  sed -i 's/変更前。/変更後。/' "$repo/doc.md"
  run bash -c 'cd "$1" && bash "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
  [ "$status" -eq 0 ]
  printf '%s\n%s。\n' 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお。' "$(printf 'う%.0s' {1..120})" > "$repo/doc.md"
  run bash -c 'cd "$1" && bash "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
  [ "$status" -eq 1 ]
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
  run bash -c 'cd "$1" && bash "$2" --diff HEAD -- new.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
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
  run bash -c 'cd "$1" && bash "$2" --diff HEAD -- a.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
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
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/two-sentences.md"
  [ "$status" -eq 0 ]
  printf '%s\n%s。\n' "$(printf 'あ%.0s' {1..80})" "$(printf 'い%.0s' {1..40})" > "$BATS_TEST_TMPDIR/wrapped-sentence.md"
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/wrapped-sentence.md"
  [ "$status" -eq 1 ]
}

# 一文長の検査が Markdown の構造（表・箇条書き・見出し・コードブロック）を地の文と見分けることの試験。
# rep は文字 $1 を $2 回並べる。lint_tmp は残りの引数を1行ずつ書いた文書へ --file を掛ける。
rep() { local s='' k; for ((k = 0; k < $2; k++)); do s+=$1; done; printf '%s' "$s"; }
lint_tmp() {
  printf '%s\n' "${@:2}" > "$BATS_TEST_TMPDIR/$1"
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/$1"
}

@test "表だけの文書は一文長を報告しない" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/table-only.md"
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

@test "表の行も不透明な識別子の検査の対象のまま" {
  lint_tmp table-id.md '| 列 | 値 |' '|---|---|' '| 参照 | Issue #683 |'
  [ "$status" -eq 0 ]
  [[ "$output" == *":3:候補: 説明のない不透明な識別子: Issue #683"* ]]
}

@test "コードブロック内の|で始まる行を表と誤認せず、閉じのフェンスの後の長文を報告する" {
  lint_tmp pipe-in-code.md '```' '| 列 | 値 |' '|---|---|' '```' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":5:一文長: 102字"* ]]
}

@test "表の行の中のフェンス記号でコードブロックを始めない" {
  lint_tmp fence-in-table.md '| 記号 | ``` |' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":2:一文長: 102字"* ]]
}

@test "句点の無い箇条書きの項目をつながない" {
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/unpunctuated-list.md"
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
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$REPO_ROOT/scripts/fixtures/writing/lint/valid/code-block.md"
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
  run bash -c 'cd "$1" && bash "$2" --diff HEAD -- doc.md' _ "$repo" "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh"
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

@test "字下げした表の行も、字下げの深さによらず表として扱う" {
  lint_tmp indented-table.md "$(rep あ 60)" '    | 列 | 値 |' "$(rep い 60)。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "改行がCRLFの文書でも閉じのフェンスと空行を認める" {
  printf '```\r\necho\r\n```\r\n\r\n%s。\r\n' "$(rep あ 101)" > "$BATS_TEST_TMPDIR/crlf-fence.md"
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/crlf-fence.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *":5:一文長: 102字"* ]]
  printf '%s\r\n\r\n%s。\r\n' "$(rep あ 60)" "$(rep い 60)" > "$BATS_TEST_TMPDIR/crlf-blank.md"
  run bash "$REPO_ROOT/plugins/writing/scripts/lint-ja.sh" --file "$BATS_TEST_TMPDIR/crlf-blank.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "行頭のインラインコードではコードブロックを開かない" {
  lint_tmp inline-code.md '```foo``` を使う。' "$(rep あ 101)。"
  [ "$status" -eq 1 ]
  [[ "$output" == *":2:一文長: 102字"* ]]
}
