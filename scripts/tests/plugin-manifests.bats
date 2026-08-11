#!/usr/bin/env bats
load 'helpers/common'

setup() { SUT="$REPO_ROOT/scripts/validate-plugin-manifests.sh"; }

@test "正常な両marketplaceとmanifestを受け入れる" {
  run bash "$SUT" "$FIXTURES_DIR/plugin-manifests/valid"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked=1"* ]]
}
@test "片側だけのpluginを報告する" {
  run bash "$SUT" "$FIXTURES_DIR/plugin-manifests/missing-codex"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Codex marketplaceに無い: example"* ]]
}
@test "manifest version差を報告する" {
  run bash "$SUT" "$FIXTURES_DIR/plugin-manifests/version-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version不一致: example"* ]]
}
@test "対象0件を成功にしない" {
  run bash "$SUT" "$FIXTURES_DIR/plugin-manifests/empty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"対象pluginが0件"* ]]
}
@test "配布物差分とversion据え置きを報告する" {
  run env PLUGIN_REPO_ROOT="$FIXTURES_DIR/plugin-manifests/unchanged-version" bash "$REPO_ROOT/scripts/validate-plugin-versions.sh" nowhere "$FIXTURES_DIR/plugin-manifests/unchanged-version/changed-paths.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"version据え置き: example"* ]]
}
