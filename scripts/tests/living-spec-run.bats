#!/usr/bin/env bats
# living-spec プラグインの中継（scripts/run.mjs）が、検査器を探して引数・標準入力・終了コードを渡し、
# 見つからないときは hook なら何もせず、それ以外は導入の手順を出して止まることを確かめる。
# 検査器そのもの（tools/living-spec）の規則の試験は工場側の pnpm test が持つ。ここでは偽の検査器を使う。
load 'helpers/common'

setup() {
  RUN="$REPO_ROOT/plugins/living-spec/scripts/run.mjs"
  WORK="$(mktemp -d)"
  # 偽の検査器: 引数と標準入力を出し、終了コード 1 で終わる
  FAKE="$WORK/fake-checker.mjs"
  cat > "$FAKE" <<'JS'
import { readFileSync } from 'node:fs';
const input = process.argv[2] === 'hook' ? readFileSync(0, 'utf8') : '';
console.log(`args=${process.argv.slice(2).join(' ')} stdin=${input}`);
process.exit(1);
JS
  unset LIVING_SPEC_BIN
}

teardown() {
  rm -rf "$WORK"
}

@test "検査器が無ければ check は導入の手順を出して終了コード 2" {
  cd "$WORK"
  run node "$RUN" check
  [ "$status" -eq 2 ]
  [[ "$output" == *"検査器が見つからない"* ]]
  [[ "$output" == *"pnpm build"* ]]
}

@test "検査器が無ければ hook は何もせず終了コード 0" {
  run bash -c "echo '{}' | CLAUDE_PROJECT_DIR='$WORK' node '$RUN' hook"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "LIVING_SPEC_BIN が存在しないファイルを指すなら、無いものとして扱う" {
  cd "$WORK"
  LIVING_SPEC_BIN="$WORK/nope.mjs" run node "$RUN" check
  [ "$status" -eq 2 ]
  [[ "$output" == *"検査器が見つからない"* ]]
}

@test "LIVING_SPEC_BIN の検査器へ引数と標準入力を渡し、その終了コードで終わる" {
  run bash -c "echo '{\"x\":1}' | LIVING_SPEC_BIN='$FAKE' CLAUDE_PROJECT_DIR='$WORK' node '$RUN' hook"
  [ "$status" -eq 1 ]
  [[ "$output" == *'args=hook stdin={"x":1}'* ]]
  cd "$WORK"
  LIVING_SPEC_BIN="$FAKE" run node "$RUN" check --doc-missing some/root
  [ "$status" -eq 1 ]
  [[ "$output" == *"args=check --doc-missing some/root"* ]]
}

@test "根から解決できるパッケージ @kuchita-el/living-spec の bin を呼ぶ" {
  local pkg="$WORK/project/node_modules/@kuchita-el/living-spec"
  mkdir -p "$pkg/dist"
  cp "$FAKE" "$pkg/dist/living-spec.mjs"
  printf '{"name":"@kuchita-el/living-spec","bin":{"living-spec":"dist/living-spec.mjs"}}\n' > "$pkg/package.json"
  printf '{"name":"project"}\n' > "$WORK/project/package.json"
  cd "$WORK/project"
  run node "$RUN" render
  [ "$status" -eq 1 ]
  [[ "$output" == *"args=render"* ]]
}
