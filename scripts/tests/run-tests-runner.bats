#!/usr/bin/env bats
# runner 自身の挙動のうち、claude-plugin-validate スイートの skip 経路を固定する。
#
# このスイートだけが fail-closed の例外（claude を解決できなければ緑のまま実行しない）で
# あり、例外は放置すると「いつのまにか一度も走っていない」形へ退化する。skip 側だけを
# 固定すると、実体が呼ばれなくなっても緑のままになるため、実行される側（検査器が非0を
# 返せば FAILED になること）も対で固定する。
load 'helpers/common'

setup() { RUNNER="$REPO_ROOT/scripts/run-tests.sh"; }

@test "claude を解決できない場合は SKIPPED として理由を展開し緑で終わる" {
  run env PATH=/usr/bin:/bin bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-plugin-validate ... SKIPPED"* ]]
  [[ "$output" == *"claude を解決できないため検査を実行していない"* ]]
  # 集計行が skip を明かさないと、全スイート実行の緑と区別がつかない。
  [[ "$output" == *"skipped: claude-plugin-validate"* ]]
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

@test "スイートが一覧と実体の双方に登録されている" {
  run bash "$RUNNER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-plugin-validate"* ]]
  # 実体が未定義のスイート名は run_one が非0で弾く。--list に載るだけの登録漏れを検出する。
  run grep -c 'claude-plugin-validate)' "$RUNNER"
  [ "$output" -eq 1 ]
}
