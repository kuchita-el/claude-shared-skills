#!/usr/bin/env bats

root="$BATS_TEST_DIRNAME/../.."

@test "createのfrontmatterとhost adapter契約が揃う" {
  skill="$root/plugins/dev-workflow/skills/create-issue/SKILL.md"
  run sed -n '1,/^---$/p' "$skill"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name: create-issue"* ]]
  [[ "$output" == *"DoRを満たしたIssueを生成する"* ]]
  [[ "$output" == *"Issue起票時"* ]]
  for tool in Read AskUserQuestion Write 'Bash(gh issue create*)'; do [[ "$output" == *"$tool"* ]]; done
}

@test "createは不足と拒否を停止として定義する" {
  run grep -E 'decision=stop|writes=\[\]|DoR.*全項目|Codex|approval' "$root/plugins/dev-workflow/skills/create-issue/SKILL.md"
  [ "$status" -eq 0 ]
  run jq -e '.decision == "stop" and (.unresolved|length > 0) and (.writes|length == 0)' "$root/scripts/fixtures/dev-workflow/create/missing-ac/expected.json"
  [ "$status" -eq 0 ]
  run jq -e '.decision == "stop" and (.writes|length == 0)' "$root/scripts/fixtures/dev-workflow/create/rejected/expected.json"
  [ "$status" -eq 0 ]
}

@test "create skillは500行以内で一段参照に留まる" {
  skill="$root/plugins/dev-workflow/skills/create-issue/SKILL.md"
  [ "$(wc -l < "$skill")" -le 500 ]
  run grep -E '\.\./|references/[^` ]+.*references/' "$skill"
  [ "$status" -eq 1 ]
}
