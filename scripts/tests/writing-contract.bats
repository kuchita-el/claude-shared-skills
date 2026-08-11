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

@test "reviewerはF1/F3/F4/F5を省略せず独立入力で判定する" {
  reviewer="$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-reviewer.md"
  run cat "$reviewer"
  [[ "$output" == *"F1"* && "$output" == *"F3"* && "$output" == *"F4"* && "$output" == *"F5"* ]]
  [[ "$output" == *"ruleId"* && "$output" == *"severity"* && "$output" == *"evidence"* && "$output" == *"suggestion"* ]]
  [[ "$output" == *"素材、起草経緯"* ]]
  [[ "$output" == *"根拠が主張から離れている"* ]]
}

@test "compatibility matrixとpermission ledgerの全fixtureを持つ" {
  root="$BATS_TEST_DIRNAME/../.."
  run jq -e 'length > 0 and all(.[]; (.fixtures|length > 0))' "$root/plugins/writing/compatibility.json"
  [ "$status" -eq 0 ]
  run jq -e 'length >= 5 and all(.[]; has("requiredOperation") and has("witness") and has("narrowerAlternative") and has("verdict"))' "$root/plugins/writing/permission-ledger.json"
  [ "$status" -eq 0 ]
}

@test "reviewerの正負fixtureと最大2回契約が揃う" {
  root="$BATS_TEST_DIRNAME/../.."
  for rule in f1 f3 f4 f5; do
    [ -f "$root/scripts/fixtures/writing/reviewer/${rule}-valid.md" ]
    [ -f "$root/scripts/fixtures/writing/reviewer/${rule}-invalid.md" ]
  done
  run grep -E '修正回数0/1/2|2回後もerror|status=unresolved' "$root/plugins/writing/agents/doc-reviewer.md"
  [ "$status" -eq 0 ]
}

@test "allowlistと免除語集合を導入しない" {
  root="$BATS_TEST_DIRNAME/../.."
  run grep -R -E 'allowlist path|登録簿|免除語集合' "$root/plugins/writing/compatibility.json" "$root/plugins/writing/permission-ledger.json" "$root/scripts/fixtures/writing"
  [ "$status" -eq 1 ]
}
