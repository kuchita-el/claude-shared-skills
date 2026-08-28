#!/usr/bin/env bats
load 'helpers/common'

# 作者向け規約2本（context-budget / subagent-execution-parameters）を配布物外へ搬出し、
# 孤立ファイル workflow-patterns を削除した状態を固定する。
#
# 検査は「旧パス文字列がどこにも現れないこと」であり、行番号にも版にも依存しない。
# 除外集合は凍結記録・観測記録に限る（設計spec 2026-08-28 節1「据え置く」）:
#   docs/adr/                                                        旧ADR決定文（上書きADRで決着）
#   docs/development/adr-demotion-cases/                             当時の観測記録
#   docs/superpowers/specs/2026-07-25-subagent-exec-params-design.md 過去spec
#   docs/qa/plugin-bp-audit-20260722.md                              監査記録

@test "搬出先が実在し新パスが CLAUDE.md から引かれている" {
  [ -f "$REPO_ROOT/docs/references/context-budget.md" ]
  [ -f "$REPO_ROOT/docs/references/subagent-execution-parameters.md" ]
  # 不在検査だけでは走査0件でも緑になるため、走査面が生きていることを
  # 「新パスが引かれている側」の照合で確かめる。
  run grep -n -F \
    -e 'docs/references/context-budget.md' \
    -e 'docs/references/subagent-execution-parameters.md' \
    "$REPO_ROOT/CLAUDE.md"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 2 ]
}

@test "旧パス3本が CLAUDE.md と配布物に残らない" {
  local plugin_root="$REPO_ROOT/plugins"
  # 台帳（plugin-path-reference-ledger.md）の走査に拾われないよう、
  # behavior-invariants.bats と同じ形で literal を分割する。
  local refs='plugins/'"dev-workflow"'/references'
  [ ! -e "$plugin_root/dev-workflow/references/context-budget.md" ]
  [ ! -e "$plugin_root/dev-workflow/references/subagent-execution-parameters.md" ]
  [ ! -e "$plugin_root/dev-workflow/references/workflow-patterns.md" ]
  run grep -R -n -F \
    -e "$refs/context-budget.md" \
    -e "$refs/subagent-execution-parameters.md" \
    -e "$refs/workflow-patterns.md" \
    "$REPO_ROOT/CLAUDE.md" "$plugin_root"
  [ "$status" -eq 1 ]
}

@test "旧パス3本が現行文書（凍結記録を除く）に残らない" {
  # 台帳（plugin-path-reference-ledger.md）の走査に拾われないよう、
  # behavior-invariants.bats と同じ形で literal を分割する。
  local refs='plugins/'"dev-workflow"'/references'
  run grep -R -n -F \
    --exclude-dir=adr \
    --exclude-dir=adr-demotion-cases \
    --exclude=2026-07-25-subagent-exec-params-design.md \
    --exclude=plugin-bp-audit-20260722.md \
    -e "$refs/context-budget.md" \
    -e "$refs/subagent-execution-parameters.md" \
    -e "$refs/workflow-patterns.md" \
    "$REPO_ROOT/docs"
  [ "$status" -eq 1 ]
}
