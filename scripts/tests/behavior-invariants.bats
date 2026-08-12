#!/usr/bin/env bats
load 'helpers/common'

@test "抽象規約の正本がトップレベルへ昇格して旧共有参照が消える" {
  local plugin_root="$REPO_ROOT/plugins"
  [ -f "$REPO_ROOT/docs/behavior-invariants.md" ]
  [ ! -e "$plugin_root/dev-workflow/references/behavior-invariants.md" ]
  local old_ref='plugins/'"dev-workflow"'/references/behavior-invariants.md'
  run grep -R -n -E --exclude-dir=adr --exclude-dir=plans "$old_ref|\$\{CLAUDE_PLUGIN_ROOT\}/references/behavior-invariants\.md" \
    "$REPO_ROOT/CLAUDE.md" "$plugin_root" "$REPO_ROOT/docs"
  [ "$status" -eq 1 ]
}

@test "全対象に文脈固有の範囲・成果物・停止・変更境界がある" {
  local plugin_root="$REPO_ROOT/plugins"
  local files=(
    "$plugin_root/adr/skills/manage-adr/SKILL.md"
    "$plugin_root/dev-workflow/skills/create-issue/SKILL.md"
    "$plugin_root/dev-workflow/skills/refine-issue/SKILL.md"
    "$plugin_root/dev-workflow/skills/plan-issue/SKILL.md"
    "$plugin_root/dev-workflow/skills/implementation/SKILL.md"
    "$plugin_root/domain-design/skills/event-storming/SKILL.md"
    "$plugin_root/domain-design/skills/domain-modeling/SKILL.md"
    "$plugin_root/dependency-insight/skills/dependency-check/SKILL.md"
    "$plugin_root/growth/skills/capture/SKILL.md"
    "$plugin_root/growth/skills/distill/SKILL.md"
    "$plugin_root/growth/skills/intake/SKILL.md"
    "$plugin_root/growth/skills/promote/SKILL.md"
    "$plugin_root/writing/skills/write-doc/SKILL.md"
    "$plugin_root/dev-workflow/agents/issue-refiner.md"
    "$plugin_root/dev-workflow/agents/issue-refiner-batch.md"
  )
  local file
  for file in "${files[@]}"; do
    [ -f "$file" ]
    grep -qiE '対象|範囲' "$file"
    grep -qiE '成果物|出力' "$file"
    grep -qiE '停止|未決|保留|Not Ready' "$file"
    grep -qiE '変更|境界|対象外' "$file"
  done
}
