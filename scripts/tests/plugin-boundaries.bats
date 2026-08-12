#!/usr/bin/env bats
load 'helpers/common'
SUT="$REPO_ROOT/scripts/check-plugin-boundary-decision.sh"

@test "決定台帳不在はFAIL" {
  run bash "$SUT" "$REPO_ROOT" "$FIXTURES_DIR/plugin-boundaries/missing-ledger.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"決定台帳が無い"* ]]
}
@test "正例のschema・graph・承認を受け入れる" {
  run bash "$SUT" "$REPO_ROOT" "$REPO_ROOT/docs/development/plugin-boundary-decision.md"
  [ "$status" -eq 0 ]
}
@test "判定項目欠落を拒否する" {
  run bash "$SUT" "$REPO_ROOT" "$FIXTURES_DIR/plugin-boundaries/missing-check/decision.json"
  [ "$status" -eq 1 ]; [[ "$output" == *"判定項目集合不一致"* ]]
}
@test "failありsplitを拒否する" {
  run bash "$SUT" "$REPO_ROOT" "$FIXTURES_DIR/plugin-boundaries/wrong-decision/decision.json"
  [ "$status" -eq 1 ]; [[ "$output" == *"decision-mismatch"* ]]
}
@test "承認IDの取り違えを拒否する" {
  run bash "$SUT" "$REPO_ROOT" "$FIXTURES_DIR/plugin-boundaries/wrong-approval/decision.json"
  [ "$status" -eq 1 ]; [[ "$output" == *"approval-mismatch"* ]]
}
