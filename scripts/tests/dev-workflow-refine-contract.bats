#!/usr/bin/env bats

root="$BATS_TEST_DIRNAME/../.."

@test "refine単件は全DoR項目とNot Ready境界を持つ" {
  skill="$root/plugins/dev-workflow/skills/refine-issue/SKILL.md"
  run sed -n '1,/^---$/p' "$skill"
  [[ "$output" == *"DoRを精査する"* && "$output" == *"着手前精査時"* ]]
  for tool in 'Bash(gh issue view*)' 'Bash(bash *skills/refine-issue/scripts/prepare-issues.sh*)' Agent; do [[ "$output" == *"$tool"* ]]; done
  run grep -E '全項目|Not Ready|Codex|定義全文|projectDor' "$skill" "$root/plugins/dev-workflow/agents/issue-refiner.md"
  [ "$status" -eq 0 ]
}

@test "refineの単件fixtureはready境界を固定する" {
  run jq -e '.status == "Ready" and (.checks|length > 0)' "$root/scripts/fixtures/dev-workflow/refine/single-ready/expected.json"
  [ "$status" -eq 0 ]
  run jq -e '.status == "Not Ready" and (.unresolved|length == 1)' "$root/scripts/fixtures/dev-workflow/refine/single-not-ready/expected.json"
  [ "$status" -eq 0 ]
}

@test "refine skillは500行以内で一段参照に留まる" {
  skill="$root/plugins/dev-workflow/skills/refine-issue/SKILL.md"
  [ "$(wc -l < "$skill")" -le 500 ]
  run grep -E '\.\./|references/[^` ]+.*references/' "$skill"
  [ "$status" -eq 1 ]
}
