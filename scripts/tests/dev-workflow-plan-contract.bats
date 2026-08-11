#!/usr/bin/env bats
root="$BATS_TEST_DIRNAME/../.."
@test "planは3入力とAC対応・衝突回避を持つ" {
  run grep -E 'Issueなし|固定入力|AC.*対応|連番|Codex|decision-request' "$root/plugins/dev-workflow/skills/plan-issue/SKILL.md"
  [ "$status" -eq 0 ]
}
@test "plan reviewerは独立性不足で停止する" {
  run grep -E '独立汎用sub-agent|独立文脈|定義完全注入|停止' "$root/plugins/dev-workflow/agents/plan-reviewer.md" "$root/plugins/dev-workflow/skills/plan-issue/SKILL.md"
  [ "$status" -eq 0 ]
}
@test "plan fixtures exist" {
  [ -d "$root/scripts/fixtures/dev-workflow/plan" ]
}
