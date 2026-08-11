#!/usr/bin/env bats
load 'helpers/common'

@test "参照台帳の正例は双方向一致する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-path-references.sh" "$FIXTURES_DIR/plugin-path-references/valid/repo" "$FIXTURES_DIR/plugin-path-references/valid/docs/development/plugin-path-reference-ledger.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked=1 missing=0 stale=0"* ]]
}
@test "未登録参照を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-path-references.sh" "$FIXTURES_DIR/plugin-path-references/unregistered/repo" "$FIXTURES_DIR/plugin-path-references/unregistered/docs/development/plugin-path-reference-ledger.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unregistered: scripts/example.sh:1:plugins/adr"* ]]
}
@test "台帳だけに残った参照を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-path-references.sh" "$FIXTURES_DIR/plugin-path-references/stale-ledger/repo" "$FIXTURES_DIR/plugin-path-references/stale-ledger/docs/development/plugin-path-reference-ledger.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale-ledger: scripts/removed.sh:4:plugins/writing"* ]]
}
@test "marketplaceにないplugin名も実ディレクトリから検出する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-path-references.sh" "$FIXTURES_DIR/plugin-path-references/dynamic/repo" "$FIXTURES_DIR/plugin-path-references/dynamic/docs/development/plugin-path-reference-ledger.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unregistered: scripts/example.sh:1:plugins/newplugin"* ]]
}
