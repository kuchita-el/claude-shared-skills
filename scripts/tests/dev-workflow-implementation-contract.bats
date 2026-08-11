#!/usr/bin/env bats

root="$BATS_TEST_DIRNAME/../.."

@test "implementationのfrontmatterと全件完了境界が固定される" {
  skill="$root/plugins/dev-workflow/skills/implementation/SKILL.md"
  run sed -n '1,/^---$/p' "$skill"
  [[ "$output" == *"Issue/planをTDD実装しレビュー・CI・PRを結審する"* ]]
  [[ "$output" == *"コード変更を伴う実装時"* ]]
  run grep -E 'resolved\|unresolved\|blocked\|unknown|1件でも|inline' "$skill"
  [ "$status" -eq 0 ]
}

@test "AC review CI の未解決fixtureは完了を拒否する" {
  for f in ac-unresolved review-blocker ci-red ci-unknown dependency-missing; do
    [ -f "$root/scripts/fixtures/dev-workflow/implementation/$f/expected.json" ]
  done
  for file in "$root"/scripts/fixtures/dev-workflow/implementation/*/expected.json; do
    run jq -e '.status != "Ready"' "$file"
    [ "$status" -eq 0 ]
  done
}
