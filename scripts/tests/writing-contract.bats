#!/usr/bin/env bats

@test "write-docのskillとwriterが配置される" {
  [ -f "$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md" ]
  [ -f "$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-writer.md" ]
}

@test "write-docのfrontmatterとexact allowed-toolsが契約に一致する" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  run sed -n '1,/^---$/p' "$skill"
  [[ "$output" == *"name: write-doc"* ]]
  [[ "$output" == *"文書を起草・検査・独立レビューする"* ]]
  [[ "$output" == *"文書作成または改稿時"* ]]
  for tool in Read Write Edit 'Bash(bash *scripts/lint-ja.sh*)' Agent; do
    [[ "$output" == *"$tool"* ]]
  done
}

@test "素材なし停止とprofile優先順が明記される" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  run cat "$skill"
  [[ "$output" == *"materials=[]"* ]]
  [[ "$output" == *"status=blocked"* ]]
  [[ "$output" == *"writes=[]"* ]]
  [[ "$output" == *'${CLAUDE_PROJECT_DIR}/.claude/writing/type-profiles.md'* ]]
  [[ "$output" == *"references/document-type-profiles.md"* ]]
}

@test "writerにmodelとeffort frontmatterがある" {
  run sed -n '1,/^---$/p' "$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-writer.md"
  [[ "$output" == *"model: sonnet"* ]]
  [[ "$output" == *"effort: high"* ]]
}

@test "skillは段階的開示と自己完結した処理を持つ" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  lines=$(wc -l < "$skill")
  [ "$lines" -le 500 ]
  run grep -E '\.\./|references/[^` ]+.*references/' "$skill"
  [ "$status" -eq 1 ]
  run grep -E '素材、起草経緯|最大2回|F1、F3、F4、F5' "$skill"
  [ "$status" -eq 0 ]
}

@test "入力fixtureは完全入力と素材不足を分ける" {
  run jq -e '.materials|length == 1' "$BATS_TEST_DIRNAME/../fixtures/writing/write-doc/complete-input.json"
  [ "$status" -eq 0 ]
  run jq -e '.materials|length == 0' "$BATS_TEST_DIRNAME/../fixtures/writing/write-doc/missing-material.json"
  [ "$status" -eq 0 ]
}
