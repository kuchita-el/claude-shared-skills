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
