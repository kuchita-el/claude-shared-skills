#!/usr/bin/env bats
load 'helpers/common'

@test "抽象規約の正本がトップレベルへ昇格して旧共有参照が消える" {
  [ -f "$REPO_ROOT/docs/behavior-invariants.md" ]
  [ ! -e "$REPO_ROOT/plugins/dev-workflow/references/behavior-invariants.md" ]
  run rg -n 'plugins/dev-workflow/references/behavior-invariants\.md|\$\{CLAUDE_PLUGIN_ROOT\}/references/behavior-invariants\.md' \
    "$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/plugins" "$REPO_ROOT/docs" \
    --glob '!docs/adr/**' --glob '!docs/superpowers/plans/**'
  [ "$status" -eq 1 ]
}

@test "全対象に文脈固有の範囲・成果物・停止・変更境界がある" {
  local files=(
    "$REPO_ROOT/plugins/adr/skills/manage-adr/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/create-issue/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/refine-issue/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/plan-issue/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/implementation/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/event-storming/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/domain-modeling/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/skills/dependency-check/SKILL.md"
    "$REPO_ROOT/plugins/growth/skills/capture/SKILL.md"
    "$REPO_ROOT/plugins/growth/skills/distill/SKILL.md"
    "$REPO_ROOT/plugins/growth/skills/intake/SKILL.md"
    "$REPO_ROOT/plugins/growth/skills/promote/SKILL.md"
    "$REPO_ROOT/plugins/writing/skills/write-doc/SKILL.md"
    "$REPO_ROOT/plugins/dev-workflow/agents/issue-refiner.md"
    "$REPO_ROOT/plugins/dev-workflow/agents/issue-refiner-batch.md"
  )
  local file
  for file in "${files[@]}"; do
    [ -f "$file" ]
    rg -qi '対象|範囲' "$file"
    rg -qi '成果物|出力' "$file"
    rg -qi '停止|未決|保留|Not Ready' "$file"
    rg -qi '変更|境界|対象外' "$file"
  done
}
