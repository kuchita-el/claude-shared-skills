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
