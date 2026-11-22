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

# workflow の steps を step 単位のブロックとして読み、関心のある step の性質を1行の facts に
# して出す。「その文字列がファイルのどこかに在ること」だけを見ると、env を別の step へ移す・
# `if: false` を足す・run へ引数を足す、のいずれの変異でも担保が消えたまま緑になる。担保は
# 「runner を起動するその step に要求モードが載っていること」であり、step との結び付きを見る
# 必要がある。
#
# 読み方は workflow の字下げの形（step は6桁の `- `、step のキーは8桁、env の子は10桁）を
# 前提にする。形が崩れれば kind が付かず件数が 0 になり、呼び出し側のケースが赤になる。
workflow_step_facts() {
  awk '
    function flush(   i, l, cmd, key, kind, has_if, has_coe, envval) {
      if (n == 0) return
      kind = ""; has_if = 0; has_coe = 0; envval = "-"; key = ""
      for (i = 1; i <= n; i++) {
        l = block[i]
        if (l ~ /^      - run:[ \t]/ || l ~ /^        run:[ \t]/) {
          cmd = l
          sub(/^[^:]*:[ \t]*/, "", cmd)
          if (cmd == "bash scripts/run-tests.sh") kind = "runner"
          else if (cmd ~ /^npm install -g @anthropic-ai\/claude-code@[0-9]+\.[0-9]+\.[0-9]+$/) kind = "install-cli"
        }
        if (l ~ /^        if:/) has_if = 1
        if (l ~ /^        continue-on-error:/) has_coe = 1
        if (l ~ /^        [A-Za-z_-]+:/) { key = l; sub(/^[ \t]*/, "", key); sub(/:.*$/, "", key) }
        if (key == "env" && l ~ /^          RUN_TESTS_REQUIRE_ALL_SUITES:[ \t]/) {
          envval = l
          sub(/^[^:]*:[ \t]*/, "", envval)
        }
      }
      if (kind != "") printf "%s if=%d continue-on-error=%d require-all-suites=%s\n", kind, has_if, has_coe, envval
      n = 0
    }
    /^      - / { flush() }
    /^      / { block[++n] = $0 }
    END { flush() }
  ' "$1"
}

@test "claude を解決できない場合は SKIPPED として理由を展開し緑で終わる" {
  run env RUN_TESTS_REQUIRE_ALL_SUITES=0 PATH=/usr/bin:/bin bash "$RUNNER" claude-plugin-validate
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
  run env RUN_TESTS_REQUIRE_ALL_SUITES=0 PATH="$stub_dir:/usr/bin:/bin" bash "$RUNNER" claude-plugin-validate
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
  run env RUN_TESTS_REQUIRE_ALL_SUITES=0 PATH="$stub_dir:/usr/bin:/bin" bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude-plugin-validate ... FAILED (exit 99"* ]]
  [[ "$output" != *"SKIPPED"* ]]
  [[ "$output" != *"skipped:"* ]]
}

@test "RUN_TESTS_REQUIRE_ALL_SUITES に 1 / 0 以外を渡すと理由付きで落ちる" {
  # true / yes を黙って「skip 可」と解釈すると、要求モードのつもりで立てた運用者が検査の
  # 走らない緑を受け取る。担保の有無が値の綴りで静かに変わらないことを固定する。
  run env PATH=/usr/bin:/bin RUN_TESTS_REQUIRE_ALL_SUITES=true bash "$RUNNER" claude-plugin-validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"RUN_TESTS_REQUIRE_ALL_SUITES は 1 か 0 のみ受け付けます"* ]]
  [[ "$output" != *"SKIPPED"* ]]
  [[ "$output" != *"all suites passed"* ]]
}

@test "CI が runner を起動する step で RUN_TESTS_REQUIRE_ALL_SUITES=1 を立てて呼ぶ" {
  workflow="$REPO_ROOT/.github/workflows/test.yml"
  [ -f "$workflow" ]
  run workflow_step_facts "$workflow"
  [ "$status" -eq 0 ]
  # runner を起動する step がちょうど1件あり、走ることを妨げる鍵を持たず、その step 自身の
  # env に要求モードが載っていること。件数まで見るのは、同じ run を持つ step が増えたときに
  # どちらに env が載っているか分からなくなるため。
  [ "$(grep -c '^runner ' <<<"$output")" -eq 1 ]
  [[ "$output" == *'runner if=0 continue-on-error=0 require-all-suites="1"'* ]]
  # 担保は CLI の導入とセットで初めて働く。導入 step が消えれば毎回 FAILED になるが、
  # 版の固定が外れる変異は赤にならないため、ここで固定する。
  [ "$(grep -c '^install-cli ' <<<"$output")" -eq 1 ]
  [[ "$output" == *'install-cli if=0 continue-on-error=0'* ]]
}

@test "workflow から担保を落とす変異を facts が捉える" {
  # 上のケースが観測する量（step との結び付き）を動かす変異を並べ、facts が変異ごとに別の
  # 値へ動くことを示す。文字列の存在だけを見ていた頃は、ここに並ぶ変異1〜3 が緑で通った。
  workflow="$REPO_ROOT/.github/workflows/test.yml"
  mutant="$BATS_TEST_TMPDIR/test.yml"

  # 変異1: runner の step へ if: を足し、走らないようにする
  sed 's|^        run: bash scripts/run-tests.sh$|        if: false\n        run: bash scripts/run-tests.sh|' "$workflow" >"$mutant"
  run workflow_step_facts "$mutant"
  [[ "$output" == *'runner if=1'* ]]

  # 変異2: runner の起動に引数を足し、スイートを絞る
  sed 's|^        run: bash scripts/run-tests.sh$|        run: bash scripts/run-tests.sh bats|' "$workflow" >"$mutant"
  run workflow_step_facts "$mutant"
  [ "$(grep -c '^runner ' <<<"$output")" -eq 0 ]

  # 変異3: env を runner の step から CLI 導入の step へ移す
  awk '
    /^          RUN_TESTS_REQUIRE_ALL_SUITES: "1"$/ { next }
    /^        env:$/ { next }
    { print }
    /npm install -g @anthropic-ai\/claude-code@/ {
      print "        env:"
      print "          RUN_TESTS_REQUIRE_ALL_SUITES: \"1\""
    }
  ' "$workflow" >"$mutant"
  run workflow_step_facts "$mutant"
  [[ "$output" == *'runner if=0 continue-on-error=0 require-all-suites=-'* ]]
  [[ "$output" == *'install-cli if=0 continue-on-error=0 require-all-suites="1"'* ]]

  # 変異4: CLI の版の固定を外す
  sed -E 's|(@anthropic-ai/claude-code)@[0-9.]+|\1|' "$workflow" >"$mutant"
  run workflow_step_facts "$mutant"
  [ "$(grep -c '^install-cli ' <<<"$output")" -eq 0 ]

  # 変異5: 要求モードを落とす
  sed 's|RUN_TESTS_REQUIRE_ALL_SUITES: "1"|RUN_TESTS_REQUIRE_ALL_SUITES: "0"|' "$workflow" >"$mutant"
  run workflow_step_facts "$mutant"
  [[ "$output" == *'require-all-suites="0"'* ]]
}

@test "スイートが一覧と実体の双方に登録されている" {
  run bash "$RUNNER" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-plugin-validate"* ]]
  # 実体が未定義のスイート名は run_one が非0で弾く。--list に載るだけの登録漏れを検出する。
  run grep -c 'claude-plugin-validate) claude plugin validate' "$RUNNER"
  [ "$output" -eq 1 ]
}

@test "project-memory スイートが一覧と実体の双方に登録され、Task Memory の残留を見ない" {
  run bash "$RUNNER" --list
  [ "$status" -eq 0 ]
  [ "$(grep -cx 'project-memory' <<<"$output")" -eq 1 ]
  # 実体は、記録の形式と索引の一致だけを見る。--no-task-memory を付けると、作業中のブランチで
  # commit できなくなる（runner は commit ゲートからも走る）。行の終わりまでを照合して、付いていないことを見る。
  run grep -c '^ *project-memory) node plugins/shared-memory/scripts/memory.mjs check docs/memory ;;$' "$RUNNER"
  [ "$output" -eq 1 ]
}

# Task Memory の残留を見るワークフロー（.github/workflows/task-memory.yml）の配線を、facts にして出す。
# 見るのは3つである。いつ起動するか（on: のブロックの全体）、job がいつ走るか（job の if:）、
# 検査器を --no-task-memory つきで呼ぶ step が、条件なしで走るか。
# コマンドは行の終わりまでを照合する。--no-task-memory を落とすと、ワークフロー自身は緑のまま、
# 残留の検出だけが止まる。その退行を、ここで赤にする。
#
# 読み方は字下げの形（on: の子は2桁以上、job のキーは4桁、step は6桁の `- `、step のキーは8桁）を
# 前提にする。形が崩れれば facts が欠け、呼び出し側のケースが赤になる。
task_memory_workflow_facts() {
  awk '
    function flush(   i, l, cmd, kind, has_if, has_coe) {
      if (n == 0) return
      kind = ""; has_if = 0; has_coe = 0
      for (i = 1; i <= n; i++) {
        l = block[i]
        if (l ~ /^      - run:[ \t]/ || l ~ /^        run:[ \t]/) {
          cmd = l
          sub(/^[^:]*:[ \t]*/, "", cmd)
          if (cmd == "mise exec -- node plugins/shared-memory/scripts/memory.mjs check docs/memory --no-task-memory") kind = "check"
        }
        if (l ~ /^        if:/) has_if = 1
        if (l ~ /^        continue-on-error:/) has_coe = 1
      }
      if (kind != "") printf "%s if=%d continue-on-error=%d\n", kind, has_if, has_coe
      n = 0
    }
    /^[ \t]*(#.*)?$/ { next }
    /^[^ \t]/ { flush(); in_on = ($0 == "on:"); in_steps = 0; if (in_on) { on = "on:" } ; next }
    in_on { on = on "|" $0; next }
    /^    if:/ { sub(/^    if:[ \t]*/, ""); print "job-if " $0; next }
    /^    continue-on-error:/ { print "job-continue-on-error"; next }
    /^    steps:/ { in_steps = 1; next }
    in_steps && /^      - / { flush() }
    in_steps { block[++n] = $0 }
    END { flush(); print on }
  ' "$1"
}

@test "Task Memory の残留を見るワークフローが、main へ入るツリーで検査器を --no-task-memory つきで呼ぶ" {
  local workflow="$REPO_ROOT/.github/workflows/task-memory.yml"
  [ -f "$workflow" ]
  run task_memory_workflow_facts "$workflow"
  [ "$status" -eq 0 ]
  # 起動: PR の作成・更新・再開・編集（base の付け替えを含む）と、main への push。
  [ "$(grep -cxF 'on:|  pull_request:|    types: [opened, synchronize, reopened, edited]|  push:|    branches:|      - main' <<<"$output")" -eq 1 ]
  # job の条件: push か、base が main の PR。job は1つで、失敗を握りつぶさない。
  [ "$(grep -c '^job-if ' <<<"$output")" -eq 1 ]
  [ "$(grep -cxF "job-if github.event_name == 'push' || github.base_ref == 'main'" <<<"$output")" -eq 1 ]
  [ "$(grep -c '^job-continue-on-error' <<<"$output")" -eq 0 ]
  # 検査器を呼ぶ step: 1つだけ在り、条件も continue-on-error も持たない。
  [ "$(grep -c '^check ' <<<"$output")" -eq 1 ]
  [ "$(grep -cx 'check if=0 continue-on-error=0' <<<"$output")" -eq 1 ]
}

@test "Task Memory のワークフローから配線を落とす変異を facts が捉える" {
  local workflow="$REPO_ROOT/.github/workflows/task-memory.yml" mutant
  mutant="$BATS_TEST_TMPDIR/task-memory.yml"

  # 変異1: 検査器の呼び出しから --no-task-memory を落とす（ワークフロー自身は緑のままになる）
  sed 's| check docs/memory --no-task-memory$| check docs/memory|' "$workflow" >"$mutant"
  run cmp -s "$workflow" "$mutant"
  [ "$status" -ne 0 ]
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -c '^check ' <<<"$output")" -eq 0 ]

  # 変異2: 検査器を呼ぶ step へ if: を足し、走らないようにする
  sed 's|^        run: mise exec -- node |        if: false\n        run: mise exec -- node |' "$workflow" >"$mutant"
  run task_memory_workflow_facts "$mutant"
  [[ "$output" == *'check if=1 continue-on-error=0'* ]]

  # 変異3: 検査器を呼ぶ step の失敗を握りつぶす
  sed 's|^        run: mise exec -- node |        continue-on-error: true\n        run: mise exec -- node |' "$workflow" >"$mutant"
  run task_memory_workflow_facts "$mutant"
  [[ "$output" == *'check if=0 continue-on-error=1'* ]]

  # 変異4: 失敗しても成功で終わる形へ、コマンドを変える
  sed 's| check docs/memory --no-task-memory$| check docs/memory --no-task-memory \|\| true|' "$workflow" >"$mutant"
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -c '^check ' <<<"$output")" -eq 0 ]

  # 変異5: job の条件から、base が main の PR を外す
  sed "s/ || github.base_ref == 'main'\$//" "$workflow" >"$mutant"
  run cmp -s "$workflow" "$mutant"
  [ "$status" -ne 0 ]
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -cxF "job-if github.event_name == 'push' || github.base_ref == 'main'" <<<"$output")" -eq 0 ]

  # 変異6: job の失敗を握りつぶす
  sed 's|^    runs-on: |    continue-on-error: true\n    runs-on: |' "$workflow" >"$mutant"
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -c '^job-continue-on-error' <<<"$output")" -eq 1 ]

  # 変異7: 起動の契機から edited を外す（base の付け替えで走らなくなる）
  sed 's/, edited\]/]/' "$workflow" >"$mutant"
  run cmp -s "$workflow" "$mutant"
  [ "$status" -ne 0 ]
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -c 'types: \[opened, synchronize, reopened, edited\]' <<<"$output")" -eq 0 ]

  # 変異8: main への push の契機を外す
  awk '/^  push:$/ { skip = 3 } skip > 0 { skip--; next } { print }' "$workflow" >"$mutant"
  run cmp -s "$workflow" "$mutant"
  [ "$status" -ne 0 ]
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -c '|  push:|    branches:|      - main' <<<"$output")" -eq 0 ]

  # 変異9: PR の契機を、特定のパスの変更に絞る
  sed 's|^    types: \[\(.*\)\]$|    types: [\1]\n    paths:\n      - docs/**|' "$workflow" >"$mutant"
  run cmp -s "$workflow" "$mutant"
  [ "$status" -ne 0 ]
  run task_memory_workflow_facts "$mutant"
  [ "$(grep -cxF 'on:|  pull_request:|    types: [opened, synchronize, reopened, edited]|  push:|    branches:|      - main' <<<"$output")" -eq 0 ]
}
