#!/usr/bin/env bats
# living-spec プラグインの配布物（scripts/living-spec.mjs。tools/living-spec/src から pnpm build で作る生成物）が、
# 依存の導入なしに Node だけで動き、終了コードの契約を守ることを確かめる。
# 規則ごとの見本の照合は工場側の試験（tools/living-spec の pnpm test）が持つ。
load 'helpers/common'

setup() {
  BUNDLE="$REPO_ROOT/plugins/living-spec/scripts/living-spec.mjs"
  WORK="$(mktemp -d)"
}

# 見本（tools/living-spec/examples/<規則>/<名前>.txtar）を $WORK/<規則>/<名前> へ展開し、その根を出す
example() {
  local dest="$WORK/$1"
  node "$REPO_ROOT/tools/living-spec/test/fixture.ts" "$REPO_ROOT/tools/living-spec/examples/$1.txtar" "$dest"
  printf '%s' "$dest"
}

teardown() {
  rm -rf "$WORK"
}

@test "生成物の先頭に、手で直さないことと正本の場所がある" {
  run head -1 "$BUNDLE"
  [[ "$output" == *"生成物。手で直さない"* ]]
}

@test "違反の無い表は終了コード 0" {
  run node "$BUNDLE" check "$(example undefined-reference/pass-all-resolved)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"違反なし"* ]]
}

@test "違反のある表は終了コード 1 で規則名を出す" {
  run node "$BUNDLE" check "$(example undefined-reference/fail-uc-actor)"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[undefined-reference]"* ]]
}

@test "書き漏らしの向きは --doc-missing だけが出す" {
  run node "$BUNDLE" check "$(example requirement-missing/fail-uc-without-requirement)"
  [ "$status" -eq 0 ]
  run node "$BUNDLE" check --doc-missing "$(example requirement-missing/fail-uc-without-requirement)"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[requirement-missing]"* ]]
}

@test "表の置き場が無い根は終了コード 2" {
  run node "$BUNDLE" check "$WORK"
  [ "$status" -eq 2 ]
}

@test "描画は HTML を書き出して場所を出す" {
  root="$(example undefined-reference/pass-all-resolved)"
  run node "$BUNDLE" render "$root"
  [ "$status" -eq 0 ]
  [ -f "$root/.cache/living-spec/index.html" ]
}

@test "フックは表の置き場の無いリポジトリでは何もしない" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"$WORK/docs/rdra/actor.yaml\"}}' | CLAUDE_PROJECT_DIR='$WORK' node '$BUNDLE' hook"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/.cache" ]
}
