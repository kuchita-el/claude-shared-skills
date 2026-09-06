#!/usr/bin/env bats
# runner 自身の挙動のうち、claude-plugin-validate スイートの前提不成立の扱いを固定する。
#
# このスイートだけが fail-closed の例外（claude を解決できなければ緑のまま実行しない）で
# あり、例外は放置すると「いつのまにか一度も走っていない」形へ退化する。skip 側だけを
# 固定すると、実体が呼ばれなくなっても緑のままになるため、実行される側（検査器が非0を
# 返せば FAILED になること）も対で固定する。
#
# skip を無条件に許すと、CI が claude を導入し損ねた場合に緑のまま素通りする。担保は
# RUN_TESTS_REQUIRE_ALL_SUITES=1 であり、その挙動と、CI がその値を実際に立てていることの
# 双方をここで固定する。runner 側だけを固定しても、workflow が値を落とせば担保は消える。
load 'helpers/common'

setup() { RUNNER="$REPO_ROOT/scripts/run-tests.sh"; }

@test "claude を解決できない場合は SKIPPED として理由を展開し緑で終わる" {
  run env PATH=/usr/bin:/bin bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-plugin-validate ... SKIPPED"* ]]
  [[ "$output" == *"claude を PATH 上に解決できない"* ]]
  # 集計行が skip を明かさないと、全スイート実行の緑と区別がつかない。
  [[ "$output" == *"skipped: claude-plugin-validate"* ]]
}

@test "RUN_TESTS_REQUIRE_ALL_SUITES=1 なら前提不成立を失敗として扱う" {
  run env PATH=/usr/bin:/bin RUN_TESTS_REQUIRE_ALL_SUITES=1 bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude-plugin-validate ... FAILED (前提不成立)"* ]]
  [[ "$output" != *"SKIPPED"* ]]
  [[ "$output" != *"skipped:"* ]]
}

@test "claude を解決できる場合は実体を起動し、非0をそのまま FAILED にする" {
  stub_dir="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$stub_dir"
  printf '%s\n' '#!/usr/bin/env bash' 'echo "stub claude: 検査に失敗した"' 'exit 1' >"$stub_dir/claude"
  chmod +x "$stub_dir/claude"
  run env PATH="$stub_dir:/usr/bin:/bin" bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude-plugin-validate ... FAILED"* ]]
  [[ "$output" == *"stub claude: 検査に失敗した"* ]]
  [[ "$output" != *"SKIPPED"* ]]
}

@test "実体の終了コードが何であっても skip へ化けない" {
  # skip の合図に特定の終了コードを充てると、外部 CLI が同じ値で失敗したときに実失敗が
  # skip へ化ける。実体の終了コードの値域は本リポジトリが決められないため、化けないことを
  # 固定する。99 は以前 skip の合図に使っていた値。
  stub_dir="$BATS_TEST_TMPDIR/stub99"
  mkdir -p "$stub_dir"
  printf '%s\n' '#!/usr/bin/env bash' 'echo "stub claude: exit 99 で失敗した"' 'exit 99' >"$stub_dir/claude"
  chmod +x "$stub_dir/claude"
  run env PATH="$stub_dir:/usr/bin:/bin" bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude-plugin-validate ... FAILED (exit 99"* ]]
  [[ "$output" != *"SKIPPED"* ]]
  [[ "$output" != *"skipped:"* ]]
}

@test "CI が RUN_TESTS_REQUIRE_ALL_SUITES=1 を立てて runner を呼ぶ" {
  workflow="$REPO_ROOT/.github/workflows/test.yml"
  [ -f "$workflow" ]
  run grep -c 'RUN_TESTS_REQUIRE_ALL_SUITES: "1"' "$workflow"
  [ "$output" -eq 1 ]
  # 担保は CLI の導入とセットで初めて働く。導入 step が消えれば毎回 FAILED になるが、
  # 版の固定が外れる変異は赤にならないため、ここで固定する。
  run grep -c 'npm install -g @anthropic-ai/claude-code@[0-9]' "$workflow"
  [ "$output" -eq 1 ]
}

@test "スイートが一覧と実体の双方に登録されている" {
  run bash "$RUNNER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-plugin-validate"* ]]
  # 実体が未定義のスイート名は run_one が非0で弾く。--list に載るだけの登録漏れを検出する。
  run grep -c 'claude-plugin-validate) claude plugin validate' "$RUNNER"
  [ "$output" -eq 1 ]
}
