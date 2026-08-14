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
@test "surface-specific宣言済みの片側plugin欠落を許容する" {
  fixture="$BATS_FILE_TMPDIR/surface-specific"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/docs/references"
  growth_name=growth
  growth_path="$fixture/plugins/$growth_name"
  mkdir -p "$growth_path/.claude-plugin" "$growth_path/.codex-plugin" "$growth_path/skills/growth-skill"
  printf '%s\n' '{"name":"growth","version":"0.1.0"}' >"$growth_path/.claude-plugin/plugin.json"
  printf '%s\n' '{"name":"growth","version":"0.1.0","skills":"./skills/"}' >"$growth_path/.codex-plugin/plugin.json"
  printf '%s\n' '# growth' >"$growth_path/README.md"
  touch "$growth_path/skills/growth-skill/SKILL.md"
  jq --arg name "$growth_name" --arg source "./plugins/$growth_name" '.plugins += [{"name":$name,"source":$source}]' "$fixture/.claude-plugin/marketplace.json" >"$fixture/.claude-plugin/marketplace.json.next"
  mv "$fixture/.claude-plugin/marketplace.json.next" "$fixture/.claude-plugin/marketplace.json"
  printf '%s\n' '[{"feature":"growth","plugin":"growth","claudeLevel":"portable","codexLevel":"surface-specific","fixtures":["example"],"residualRisk":"Codexでは提供しない"}]' >"$fixture/docs/references/cross-host-compatibility.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 0 ]
}
@test "surface-specific免除でもClaude側source検査を実行する" {
  fixture="$BATS_FILE_TMPDIR/surface-specific-claude-checks"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/docs/references"
  growth_name=growth
  jq --arg name "$growth_name" --arg source "./plugins/$growth_name" '.plugins += [{"name":$name,"source":$source}]' "$fixture/.claude-plugin/marketplace.json" >"$fixture/.claude-plugin/marketplace.json.next"
  mv "$fixture/.claude-plugin/marketplace.json.next" "$fixture/.claude-plugin/marketplace.json"
  printf '%s\n' '[{"feature":"growth","plugin":"growth","claudeLevel":"portable","codexLevel":"surface-specific","fixtures":["example"],"residualRisk":"Codexでは提供しない"}]' >"$fixture/docs/references/cross-host-compatibility.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Claude source pathが無い: growth"* ]]
}
@test "surface-specific未宣言の片側plugin欠落を報告する" {
  fixture="$BATS_FILE_TMPDIR/undeclared-surface-specific"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/docs/references"
  jq '.plugins += [{"name":"growth","source":"./plugins/example"}]' "$fixture/.claude-plugin/marketplace.json" >"$fixture/.claude-plugin/marketplace.json.next"
  mv "$fixture/.claude-plugin/marketplace.json.next" "$fixture/.claude-plugin/marketplace.json"
  printf '%s\n' '[{"feature":"example","plugin":"example","claudeLevel":"portable","codexLevel":"portable","fixtures":["example"]}]' >"$fixture/docs/references/cross-host-compatibility.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Codex marketplaceに無い: growth"* ]]
}
@test "surface-specific宣言済みのClaude側plugin欠落を許容する" {
  fixture="$BATS_FILE_TMPDIR/surface-specific-claude"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/docs/references"
  jq '.plugins += [{"name":"codex-only","source":{"path":"./plugins"}}]' "$fixture/.agents/plugins/marketplace.json" >"$fixture/.agents/plugins/marketplace.json.next"
  mv "$fixture/.agents/plugins/marketplace.json.next" "$fixture/.agents/plugins/marketplace.json"
  printf '%s\n' '[{"feature":"codex-only","plugin":"codex-only","claudeLevel":"surface-specific","codexLevel":"portable","fixtures":["example"],"residualRisk":"Claudeでは提供しない"}]' >"$fixture/docs/references/cross-host-compatibility.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 0 ]
}
@test "surface-specific未宣言のClaude側plugin欠落を報告する" {
  fixture="$BATS_FILE_TMPDIR/undeclared-surface-specific-claude"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/docs/references"
  jq '.plugins += [{"name":"codex-only","source":{"path":"./plugins"}}]' "$fixture/.agents/plugins/marketplace.json" >"$fixture/.agents/plugins/marketplace.json.next"
  mv "$fixture/.agents/plugins/marketplace.json.next" "$fixture/.agents/plugins/marketplace.json"
  printf '%s\n' '[{"feature":"example","plugin":"example","claudeLevel":"portable","codexLevel":"portable","fixtures":["example"]}]' >"$fixture/docs/references/cross-host-compatibility.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Claude marketplaceに無い: codex-only"* ]]
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
@test "base refを解決できない場合は成功にしない" {
  run bash "$REPO_ROOT/scripts/validate-plugin-versions.sh" origin/does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"base refを解決できません"* ]]
}
@test "Claude/Codexのskill集合差分を報告する" {
  run bash "$REPO_ROOT/scripts/validate-plugin-manifests.sh" "$FIXTURES_DIR/plugin-manifests/skill-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"skill集合不一致: example"* ]]
}

@test "plugin間の同名skill重複を所有者付きで報告する" {
  fixture="$BATS_FILE_TMPDIR/duplicate-skill"
  cp -R "$FIXTURES_DIR/plugin-manifests/valid" "$fixture"
  mkdir -p "$fixture/plugins/other/.claude-plugin" "$fixture/plugins/other/.codex-plugin" "$fixture/plugins/other/skills/example"
  mkdir -p "$fixture/plugins/zzz/.claude-plugin" "$fixture/plugins/zzz/.codex-plugin"
  cp "$fixture/plugins/example/.claude-plugin/plugin.json" "$fixture/plugins/other/.claude-plugin/plugin.json"
  cp "$fixture/plugins/example/.codex-plugin/plugin.json" "$fixture/plugins/other/.codex-plugin/plugin.json"
  sed -i 's/"name":"example"/"name":"other"/' "$fixture/plugins/other/.claude-plugin/plugin.json" "$fixture/plugins/other/.codex-plugin/plugin.json"
  cp "$fixture/plugins/example/.claude-plugin/plugin.json" "$fixture/plugins/zzz/.claude-plugin/plugin.json"
  cp "$fixture/plugins/example/.codex-plugin/plugin.json" "$fixture/plugins/zzz/.codex-plugin/plugin.json"
  sed -i 's/"name":"example"/"name":"zzz"/' "$fixture/plugins/zzz/.claude-plugin/plugin.json" "$fixture/plugins/zzz/.codex-plugin/plugin.json"
  touch "$fixture/plugins/other/skills/example/SKILL.md"
  jq '.plugins += [{"name":"other","source":"./plugins/other"}]' "$fixture/.claude-plugin/marketplace.json" >"$fixture/.claude-plugin/marketplace.json.next" && mv "$fixture/.claude-plugin/marketplace.json.next" "$fixture/.claude-plugin/marketplace.json"
  jq '.plugins += [{"name":"other","source":{"path":"./plugins/other"}}]' "$fixture/.agents/plugins/marketplace.json" >"$fixture/.agents/plugins/marketplace.json.next" && mv "$fixture/.agents/plugins/marketplace.json.next" "$fixture/.agents/plugins/marketplace.json"
  jq '.plugins += [{"name":"zzz","source":"./plugins/zzz"}]' "$fixture/.claude-plugin/marketplace.json" >"$fixture/.claude-plugin/marketplace.json.next" && mv "$fixture/.claude-plugin/marketplace.json.next" "$fixture/.claude-plugin/marketplace.json"
  jq '.plugins += [{"name":"zzz","source":{"path":"./plugins/zzz"}}]' "$fixture/.agents/plugins/marketplace.json" >"$fixture/.agents/plugins/marketplace.json.next" && mv "$fixture/.agents/plugins/marketplace.json.next" "$fixture/.agents/plugins/marketplace.json"
  run bash "$SUT" "$fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"同名skillが複数pluginに存在します"* ]]
}
