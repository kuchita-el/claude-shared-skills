#!/usr/bin/env bats
load 'helpers/common'

@test "skill lintは0件走査を成功にしない" {
  run bash "$REPO_ROOT/scripts/validate-skills.sh" "$FIXTURES_DIR/skill-portability/empty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"検査対象skillが0件"* ]]
}
@test "正常なcompatibilityとpermission fixtureを受け入れる" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/valid"
  [ "$status" -eq 0 ]
}
@test "permission ledgerの不足字段を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/invalid-ledger"
  [ "$status" -eq 1 ]
  [[ "$output" == *"permission-ledger: missing narrowerAlternative"* ]]
}
@test "compatibility matrixのschema違反をexit 1にする" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/invalid-compatibility"
  [ "$status" -eq 1 ]
  [[ "$output" == *"compatibility: missing codexLevel"* ]]
}
@test "surface-specific行はresidualRiskを要求する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/invalid-compatibility"
  [ "$status" -eq 1 ]
  [[ "$output" == *"compatibility: missing residualRisk"* ]]
}
@test "canonical matrixのfixture名は実体へ解決する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"errors=0"* ]]
}
@test "matrixが参照するfixtureの欠落を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/invalid-fixture-reference"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fixtureが無い missing-fixture"* ]]
}
@test "SKILLからの2段参照を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/two-hop-reference"
  [ "$status" -eq 1 ]
  [[ "$output" == *"2段参照"* ]]
}
@test "growthも参照整合性検査の対象にする" {
  run bash "$REPO_ROOT/scripts/validate-plugin-portability.sh" "$FIXTURES_DIR/skill-portability/growth-broken-reference"
  [ "$status" -eq 1 ]
  [[ "$output" == *"壊れた参照"* ]]
}
