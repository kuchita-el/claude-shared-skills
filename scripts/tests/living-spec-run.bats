#!/usr/bin/env bats
# living-spec プラグインの中継（scripts/run.mjs）が、検査器を探して引数・標準入力・終了コードを渡し、
# 見つからないときは hook なら何もせず、それ以外は導入の手順を出して止まることを確かめる。
# あわせて、検査器がプラグインの前提（互換の世代）より古いときに、古い旨の1行を出して合格として返さないことを確かめる。
# 検査器そのもの（tools/living-spec）の規則の試験は工場側の pnpm test が持つ。ここでは偽の検査器を使う。
# 本物の入口のフックの範囲の判定と組み合わせた試験は、工場側の tools/living-spec/test/relay.test.ts が持つ。
load 'helpers/common'

setup() {
  RUN="$REPO_ROOT/plugins/living-spec/scripts/run.mjs"
  WORK="$(mktemp -d)"
  # 中継が前提とする互換の世代。検査器の側の値との照合は下の件が持つ
  REQUIRED="$(sed -n 's/^const REQUIRED_COMPAT = \([0-9][0-9]*\);$/\1/p' "$RUN")"
  # 偽の検査器: compat には FAKE_COMPAT を答え（未設定なら世代を持たない版のように使い方を出して終了コード 2）、
  # それ以外は引数と標準入力を出し、FAKE_STATUS（既定 1）で終わる
  FAKE="$WORK/fake-checker.mjs"
  cat > "$FAKE" <<'JS'
import { readFileSync } from 'node:fs';
if (process.argv[2] === 'compat') {
  if (process.env.FAKE_COMPAT === undefined) {
    console.error('使い方: living-spec check [--doc-missing] [根] | living-spec render [根] | living-spec hook');
    process.exit(2);
  }
  console.log(process.env.FAKE_COMPAT);
  process.exit(0);
}
const input = process.argv[2] === 'hook' ? readFileSync(0, 'utf8') : '';
console.log(`args=${process.argv.slice(2).join(' ')} stdin=${input}`);
process.exit(Number(process.env.FAKE_STATUS ?? 1));
JS
  # 偽の検査器のフック: FAKE_CONFIG_ERROR があれば範囲によらず設定の誤りで終了コード 2。
  # 編集したファイルが docs/rdra の下なら検査したものとして描き直しのファイルを書き（FAKE_RENDER_FAIL なら書かずに描き直しの失敗を出す）、
  # FAKE_VIOLATION があれば違反を標準エラーへ出して終了コード 2、無ければ 0。下に無ければ何もせず 0
  FAKE_HOOK="$WORK/fake-hook.mjs"
  cat > "$FAKE_HOOK" <<'JS'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
if (process.argv[2] === 'compat') {
  if (process.env.FAKE_COMPAT === undefined) process.exit(2);
  console.log(process.env.FAKE_COMPAT);
  process.exit(0);
}
const file = JSON.parse(readFileSync(0, 'utf8')).tool_input.file_path;
if (process.env.FAKE_CONFIG_ERROR) {
  process.stderr.write('.living-spec.json を読めない: 知らないキー x\n');
  process.exit(2);
}
if (!file.includes('/docs/rdra/')) process.exit(0);
if (process.env.FAKE_RENDER_FAIL) {
  process.stderr.write('living-spec フック: 設計の可視化を描けない（x）\n');
  process.exit(0);
}
const out = `${process.env.FAKE_OUT}/view/index.html`;
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, 'view');
if (process.env.FAKE_VIOLATION) {
  process.stderr.write('RDRA の検査で違反が 1 件ある\n[unknown-key] x\n');
  process.exit(2);
}
process.exit(0);
JS
  export FAKE_COMPAT="$REQUIRED" FAKE_OUT="$WORK"
  unset LIVING_SPEC_BIN FAKE_STATUS FAKE_VIOLATION FAKE_CONFIG_ERROR FAKE_RENDER_FAIL
}

teardown() {
  rm -rf "$WORK"
}

@test "検査器が無ければ check は導入の手順を出して終了コード 2" {
  cd "$WORK"
  run node "$RUN" check
  [ "$status" -eq 2 ]
  [[ "$output" == *"検査器が見つからない"* ]]
  [[ "$output" == *"releases/download/living-spec-"* ]]
  [[ "$output" == *"LIVING_SPEC_BIN"* ]]
  [[ "$output" != *"pnpm"* ]]
  [[ "$output" != *"build"* ]]
  [[ "$output" != *"ビルド"* ]]
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

@test "作業ディレクトリから解決できるパッケージ @kuchita-el/living-spec の bin を呼ぶ" {
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

@test "導入案内の取得のコマンドは、README の導入の節の取得のコマンドと一致する" {
  local readme="$REPO_ROOT/plugins/living-spec/README.md"
  local from_readme from_relay
  from_readme="$(awk '/^## 検査器の導入/{f=1;next} /^## /{f=0} f' "$readme" | sed 's/^[[:space:]]*//' | command grep -F 'curl -fsSL --create-dirs ' | command grep '^curl -fsSL --create-dirs ' || true)"
  [ "$(printf '%s\n' "$from_readme" | command grep -c .)" -eq 1 ]
  cd "$WORK"
  run node "$RUN" check
  [ "$status" -eq 2 ]
  from_relay="$(printf '%s\n' "$output" | sed 's/^[[:space:]]*//' | command grep '^curl ' || true)"
  [ "$(printf '%s\n' "$from_relay" | command grep -c .)" -eq 1 ]
  [ "$from_readme" = "$from_relay" ]
}

@test "中継の前提の世代は、検査器の側の互換の世代と同じ値である" {
  local checker
  checker="$(sed -n 's/^export const COMPAT = \([0-9][0-9]*\);$/\1/p' "$REPO_ROOT/tools/living-spec/src/compat.ts")"
  [ -n "$REQUIRED" ]
  [ -n "$checker" ]
  [ "$REQUIRED" = "$checker" ]
}

# 前提より古い旨の1行。README の導入の節を名指す
STALE_LINE='^living-spec の検査器が、このプラグインの前提より古い.*plugins/living-spec/README\.md.*の「検査器の導入」'

# 前提より古い検査器（世代が前提より小さい・世代を答えない・答えが整数でない）を名前で選ぶ
use_stale() {
  case "$1" in
    older) export FAKE_COMPAT=$((REQUIRED - 1)) ;;
    none) unset FAKE_COMPAT ;;
    garbage) export FAKE_COMPAT="v$REQUIRED" ;;
  esac
}

hook_input() {
  printf '{"tool_input":{"file_path":"%s"}}' "$1"
}

@test "前提より古い検査器の check・render は、出力より前に古い旨の1行を出し、違反の有無によらず終了コード 2" {
  cd "$WORK"
  local kind cmd code
  for kind in older none garbage; do
    use_stale "$kind"
    for cmd in check render; do
      for code in 0 1; do
        FAKE_STATUS="$code" LIVING_SPEC_BIN="$FAKE" run --separate-stderr node "$RUN" "$cmd"
        [ "$status" -eq 2 ] || { echo "$kind $cmd $code: status=$status"; return 1; }
        [ "${#stderr_lines[@]}" -eq 1 ]
        [[ "$stderr" =~ $STALE_LINE ]]
        [ "$output" = "args=$cmd stdin=" ]
      done
    done
  done
  # 古い旨の1行は検査器の出力より前に出る
  use_stale none
  LIVING_SPEC_BIN="$FAKE" run bash -c "node '$RUN' check 2>&1"
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" =~ $STALE_LINE ]]
  [[ "${lines[0]}" == *"検査器の互換の世代: なし"* ]]
  [ "${lines[1]}" = "args=check stdin=" ]
}

@test "前提より古い検査器のフックは、検査した編集で違反の有無によらず古い旨の1行と終了コード 2" {
  local kind violation
  hook_input "$WORK/docs/rdra/uc.yaml" > "$WORK/in.json"
  for kind in older none; do
    use_stale "$kind"
    for violation in '' 1; do
      rm -rf "$WORK/view"
      FAKE_VIOLATION="$violation" LIVING_SPEC_BIN="$FAKE_HOOK" CLAUDE_PROJECT_DIR="$WORK" \
        run --separate-stderr bash -c "node '$RUN' hook < '$WORK/in.json'"
      [ "$status" -eq 2 ] || { echo "$kind '$violation': status=$status"; return 1; }
      [[ "${stderr_lines[0]}" =~ $STALE_LINE ]]
      [ -z "$output" ]
      [ -f "$WORK/view/index.html" ]
      if [ -n "$violation" ]; then
        [ "${stderr_lines[1]}" = "RDRA の検査で違反が 1 件ある" ]
      else
        [ "${#stderr_lines[@]}" -eq 1 ]
      fi
    done
  done
}

@test "前提より古い検査器のフックでも、検査しない編集では出力も終了コードも検査器のまま" {
  local kind
  hook_input "$WORK/src/app.ts" > "$WORK/in.json"
  for kind in older none; do
    use_stale "$kind"
    FAKE_VIOLATION=1 LIVING_SPEC_BIN="$FAKE_HOOK" CLAUDE_PROJECT_DIR="$WORK" run bash -c "node '$RUN' hook < '$WORK/in.json'"
    [ "$status" -eq 0 ] || { echo "$kind: status=$status"; return 1; }
    [ -z "$output" ]
    [ ! -e "$WORK/view" ]
  done
}

@test "前提より古い検査器のフックは、書き込みの前に描き直しに失敗したときと、検査器が止めたときも古い旨の1行と終了コード 2" {
  local kind
  for kind in older none; do
    use_stale "$kind"
    hook_input "$WORK/docs/rdra/uc.yaml" > "$WORK/in.json"
    FAKE_RENDER_FAIL=1 LIVING_SPEC_BIN="$FAKE_HOOK" CLAUDE_PROJECT_DIR="$WORK" \
      run --separate-stderr bash -c "node '$RUN' hook < '$WORK/in.json'"
    [ "$status" -eq 2 ] || { echo "$kind render: status=$status"; return 1; }
    [[ "${stderr_lines[0]}" =~ $STALE_LINE ]]
    [ "${stderr_lines[1]}" = "living-spec フック: 設計の可視化を描けない（x）" ]
    # 設定の誤りは範囲によらず検査器が止める。古い検査器が知らないキーで止めることがあるので、古い旨も出す
    hook_input "$WORK/src/app.ts" > "$WORK/in.json"
    FAKE_CONFIG_ERROR=1 LIVING_SPEC_BIN="$FAKE_HOOK" CLAUDE_PROJECT_DIR="$WORK" \
      run --separate-stderr bash -c "node '$RUN' hook < '$WORK/in.json'"
    [ "$status" -eq 2 ] || { echo "$kind config: status=$status"; return 1; }
    [ "${stderr_lines[0]}" = ".living-spec.json を読めない: 知らないキー x" ]
    [[ "${stderr_lines[1]}" =~ $STALE_LINE ]]
  done
}

@test "前提を満たす検査器では古い旨の1行を出さず、出力と終了コードは検査器のまま" {
  cd "$WORK"
  local compat cmd code violation
  hook_input "$WORK/docs/rdra/uc.yaml" > "$WORK/in.json"
  for compat in "$REQUIRED" $((REQUIRED + 1)); do
    export FAKE_COMPAT="$compat"
    for cmd in check render; do
      for code in 0 1; do
        FAKE_STATUS="$code" LIVING_SPEC_BIN="$FAKE" run --separate-stderr node "$RUN" "$cmd"
        [ "$status" -eq "$code" ] || { echo "$compat $cmd $code: status=$status"; return 1; }
        [ -z "$stderr" ]
        [ "$output" = "args=$cmd stdin=" ]
      done
    done
    for violation in '' 1; do
      FAKE_VIOLATION="$violation" LIVING_SPEC_BIN="$FAKE_HOOK" CLAUDE_PROJECT_DIR="$WORK" \
        run --separate-stderr bash -c "node '$RUN' hook < '$WORK/in.json'"
      if [ -n "$violation" ]; then
        [ "$status" -eq 2 ]
        [ "${stderr_lines[0]}" = "RDRA の検査で違反が 1 件ある" ]
      else
        [ "$status" -eq 0 ]
        [ -z "$stderr" ]
      fi
    done
  done
}
