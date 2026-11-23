#!/usr/bin/env bats
# scripts/run-plugin-eval.sh の検査（Issue #877 AC2・AC3）。
#
# 【主題】eval ケースは配布物 `plugins/<plugin>/` の外（リポジトリ直下 `evals/<plugin>/`）
# に置く（docs/distribution-boundary.md §2・§3）一方、`claude plugin eval` は eval の
# 置き場をプラグイン配下に限る。本スクリプトは両者を橋渡しするため、実行のたびに
# `plugins/<plugin>/` を一時ディレクトリへ複製し `evals/<plugin>/` をその複製の `evals/`
# として配置してから `claude plugin eval` を呼ぶ。
#
# 【本物の claude を呼ばない】PATH の先頭にスタブ `claude` を置いて差し替える。スタブは
# 受け取った引数と、呼ばれた時点での複製先の中身（`.claude-plugin/plugin.json` と
# `evals/<case>/prompt.md` の実在）をログへ記録するだけで、任意の終了コードで戻る。
#
# 【作業ツリーを汚さないこと】検証対象として実在の `plugins/dev-workflow`（evals を持たず
# 引数検証の負例に使う）と `plugins/dependency-insight` + `evals/dependency-insight`
# （実在の複製・配置・実行の正常系に使う）をそのまま読むが、複製先は mktemp 配下であり、
# 本体の `plugins/`・`evals/` には一切書き込まない。各正常系ケースの最後に
# `git status --porcelain` で無差分を確認する。

load 'helpers/common'

SUT="$REPO_ROOT/scripts/run-plugin-eval.sh"

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$STUB_DIR"
  # 作業場所の置き場は /tmp の外でなければならない（スクリプトが拒む）。BATS_TEST_TMPDIR は
  # /tmp の下に在りうるので、ホームの下にテストごとの置き場を作り、teardown で消す
  export XDG_CACHE_HOME="$HOME/.cache/run-plugin-eval-bats.$$.$BATS_TEST_NUMBER"
  # HOME 自体が拒否される範囲に在る実行系では、スクリプトが全ての正常系を拒むので、理由を示して飛ばす
  case "$HOME/" in
    /tmp/* | /var/tmp/* | /dev/shm/*)
      skip "HOME（$HOME）が /tmp・/var/tmp・/dev/shm の下に在り、作業場所の置き場をその外に作れない"
      ;;
  esac
}

teardown() {
  if [ -n "${XDG_CACHE_HOME:-}" ] && [ -d "$XDG_CACHE_HOME" ]; then
    chmod -R u+rwX "$XDG_CACHE_HOME" 2>/dev/null
    rm -rf "$XDG_CACHE_HOME"
  fi
}

# スタブ claude を作る。呼ばれた時点の TMPDIR と複製先のパスをログへ記録する。
# 加えて、eval が root で権限を閉じた状態を真似て、TMPDIR の下に書き込みを閉じた
# ディレクトリを作る（後始末が権限を戻してから消すことを見るため。root では権限が書き込みを
# 妨げないので、権限を戻す処理の欠落はこの検査では赤くならない）
make_stub_claude_tmpdir() {
  cat >"$STUB_DIR/claude" <<'EOF'
#!/usr/bin/env bash
log="$BATS_TEST_TMPDIR/tmpdir.log"
printf 'TMPDIR\t%s\n' "$TMPDIR" >"$log"
printf 'CLONE\t%s\n' "$3" >>"$log"
if [ -d "$TMPDIR" ]; then printf 'FACT\ttmpdir-exists\n' >>"$log"; fi
mkdir -p "$TMPDIR/claude-eval-stub/home/cwd" && touch "$TMPDIR/claude-eval-stub/home/cwd/x"
chmod 555 "$TMPDIR/claude-eval-stub/home/cwd" "$TMPDIR/claude-eval-stub/home"
exit 0
EOF
  chmod +x "$STUB_DIR/claude"
}

# スタブ claude を作る。呼ばれた引数を1行1引数でログへ、
# 「plugin eval <複製先> ...」の形なら複製先の中身の実在確認結果もログへ追記する。
# 引数: $1 終了コード
make_stub_claude() {
  local exit_code="$1"
  cat >"$STUB_DIR/claude" <<EOF
#!/usr/bin/env bash
log="$BATS_TEST_TMPDIR/claude-invocation.log"
: >"\$log"
for a in "\$@"; do printf 'ARG\t%s\n' "\$a" >>"\$log"; done
if [ "\$1" = "plugin" ] && [ "\$2" = "eval" ]; then
  clone_dir="\$3"
  if [ -f "\$clone_dir/.claude-plugin/plugin.json" ]; then
    printf 'FACT\tplugin-manifest-present\n' >>"\$log"
  else
    printf 'FACT\tplugin-manifest-missing\n' >>"\$log"
  fi
  case_count=0
  if [ -d "\$clone_dir/evals" ]; then
    case_count=\$(find "\$clone_dir/evals" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  fi
  printf 'FACT\teval-case-dirs=%s\n' "\$case_count" >>"\$log"
fi
exit $exit_code
EOF
  chmod +x "$STUB_DIR/claude"
}

@test "引数検証: プラグイン名が無いと理由付きで非0終了する" {
  run bash "$SUT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"プラグイン名を指定してください"* ]]
}

@test "引数検証: plugins/<plugin>/ が無いと理由付きで非0終了する" {
  run bash "$SUT" this-plugin-does-not-exist --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugins/this-plugin-does-not-exist/ が存在しません"* ]]
}

@test "引数検証: evals/<plugin>/ が無いと理由付きで非0終了する（実在 dev-workflow は evals を持たない）" {
  [ -d "$REPO_ROOT/plugins/dev-workflow" ]
  [ ! -d "$REPO_ROOT/evals/dev-workflow" ]
  run bash "$SUT" dev-workflow --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -ne 0 ]
  [[ "$output" == *"evals/dev-workflow/ が存在しません"* ]]
}

@test "引数検証: --output-dir が無いと理由付きで非0終了する" {
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1
  [ "$status" -ne 0 ]
  [[ "$output" == *"--output-dir を指定してください"* ]]
}

@test "引数検証: --output-dir=値 形式でも受理される（正常系まで進む）" {
  make_stub_claude 0
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 "--output-dir=$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]
}

@test "正常系: 実在 dependency-insight を複製し evals を配置して claude を呼び、引数を透過し、終了コードを透過し、後始末する" {
  make_stub_claude 0

  # 実行前後で git status の差分が生じないことを見る。evals/ がこのセッションでまだ
  # commit されていない未追跡状態でも判定できるよう、絶対的な空文字ではなく前後差分で見る。
  before_status="$(cd "$REPO_ROOT" && git status --porcelain plugins/dependency-insight evals/dependency-insight)"

  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --ablation none --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]

  log="$BATS_TEST_TMPDIR/claude-invocation.log"
  [ -f "$log" ]
  run grep -Fq $'ARG\tplugin' "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'ARG\teval' "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'ARG\t--runs' "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'ARG\t--ablation' "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'ARG\t--output-dir' "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'ARG\t'"$BATS_TEST_TMPDIR/out" "$log"; [ "$status" -eq 0 ]
  run grep -Fq $'FACT\tplugin-manifest-present' "$log"; [ "$status" -eq 0 ]

  # 実在 evals/dependency-insight/ は trigger-pos・trigger-neg・behavior-patch-update の3ケース
  run grep -Fq $'FACT\teval-case-dirs=3' "$log"; [ "$status" -eq 0 ]

  # 実行後、配布物・eval 置き場の作業ツリーの git status が実行前と変わっていない
  after_status="$(cd "$REPO_ROOT" && git status --porcelain plugins/dependency-insight evals/dependency-insight)"
  [ "$before_status" = "$after_status" ]
}

@test "終了コードの透過: claude の非0終了がそのまま返る" {
  make_stub_claude 17
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 17 ]
}

@test "後始末: 実行後に一時ディレクトリが消えている（複製先パスを記録し実行後の不在を確認する）" {
  cat >"$STUB_DIR/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "plugin" ] && [ "$2" = "eval" ]; then
  printf '%s\n' "$3" >"$BATS_TEST_TMPDIR/clone-dir-path.log"
fi
exit 0
EOF
  chmod +x "$STUB_DIR/claude"

  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]

  clone_dir="$(cat "$BATS_TEST_TMPDIR/clone-dir-path.log")"
  [ -n "$clone_dir" ]
  [ ! -e "$clone_dir" ]
  # 複製先の親（work_dir）自体も消えている
  [ ! -e "$(dirname "$clone_dir")" ]
}

@test "claude が PATH 上に無い場合、理由付きで非0終了する" {
  # /usr/bin:/bin は coreutils 一式（dirname・mktemp・cp 等、スクリプト内部が使うもの）を
  # 持つが、この環境の claude（~/.local/bin 配下）は含まない。bash 自体の解決は絶対パスで
  # 行い、env による bash の探索がこの絞り込み PATH の影響を受けないようにする。
  run env PATH="/usr/bin:/bin" "$(command -v bash)" "$SUT" dependency-insight --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -ne 0 ]
  [[ "$output" == *"claude を PATH 上に解決できません"* ]]
}

@test "TMPDIR: /tmp の外の作業場所の tmp を TMPDIR にして claude を呼び、終わったら作業場所ごと消す" {
  make_stub_claude_tmpdir
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]

  log="$BATS_TEST_TMPDIR/tmpdir.log"
  tmpdir="$(sed -n 's/^TMPDIR\t//p' "$log")"
  clone="$(sed -n 's/^CLONE\t//p' "$log")"
  physical_cache="$(cd "$XDG_CACHE_HOME" && pwd -P)"
  [[ "$tmpdir" == "$physical_cache/claude-plugin-eval/run."*"/tmp" ]]
  case "$tmpdir/" in /tmp/* | /var/tmp/* | /dev/shm/*) false ;; esac
  run grep -Fq $'FACT\ttmpdir-exists' "$log"; [ "$status" -eq 0 ]
  # 複製も同じ作業場所に在る
  [ "$(dirname "$clone")" = "$(dirname "$tmpdir")" ]
  # 書き込みを閉じたディレクトリが在っても、作業場所ごと消えている
  [ ! -e "$(dirname "$tmpdir")" ]
}

@test "TMPDIR: 作業場所の置き場が /tmp の下なら、理由付きで非0終了し、claude を呼ばない" {
  make_stub_claude_tmpdir
  XDG_CACHE_HOME="/tmp/run-plugin-eval-bats.$$.$BATS_TEST_NUMBER" PATH="$STUB_DIR:$PATH" \
    run bash "$SUT" dependency-insight --runs 1 --output-dir "$BATS_TEST_TMPDIR/out"
  rm -rf "/tmp/run-plugin-eval-bats.$$.$BATS_TEST_NUMBER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"/tmp・/var/tmp・/dev/shm の下に在ります"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/tmpdir.log" ]
}

@test "--keep-temp: 作業場所を残し、場所と消し方を示す" {
  make_stub_claude_tmpdir
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --keep-temp --output-dir "$BATS_TEST_TMPDIR/out"
  [ "$status" -eq 0 ]

  tmpdir="$(sed -n 's/^TMPDIR\t//p' "$BATS_TEST_TMPDIR/tmpdir.log")"
  work_dir="$(dirname "$tmpdir")"
  [ -d "$work_dir" ]
  [[ "$output" == *"作業場所を残しました: $work_dir"* ]]
  [[ "$output" == *"chmod -R u+rwX '$work_dir' && rm -rf '$work_dir'"* ]]
}

@test "TMPDIR: 作業場所の置き場が /tmp の下を指す symlink なら、物理パスで判定して理由付きで非0終了する" {
  make_stub_claude_tmpdir
  target="/tmp/run-plugin-eval-bats-target.$$.$BATS_TEST_NUMBER"
  mkdir -p "$target" "$XDG_CACHE_HOME"
  # 字面のパス（$XDG_CACHE_HOME/claude-plugin-eval）は /tmp の外で、実体だけが /tmp の下に在る
  ln -s "$target" "$XDG_CACHE_HOME/claude-plugin-eval"
  PATH="$STUB_DIR:$PATH" run bash "$SUT" dependency-insight --runs 1 --output-dir "$BATS_TEST_TMPDIR/out"
  rm -rf "$target"
  [ "$status" -ne 0 ]
  [[ "$output" == *"/tmp・/var/tmp・/dev/shm の下に在ります"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/tmpdir.log" ]
}
