#!/usr/bin/env bash
# PreToolUse フックの commit ゲート本体。
#
# 役割は「本当に git commit のときだけ検査を走らせる」ことに限る。何を走らせるかは
# scripts/run-tests.sh が持ち、本スクリプトは持たない（ADR drift-lint は
# adr プラグインの同梱ゲートへ分離済み）。
#
# なぜ settings.json の `if` だけでは足りないか:
#   `if` は permission rule 構文でコマンドを絞るが、コマンド名より多くを指定した
#   パターン（`Bash(git commit:*)` 等）は $()・バッククォート・$VAR を含むコマンドに
#   対して fail-open で発火する。ゲートは exit 2 でブロックするため、この誤発火は
#   「検査が違反状態の間、$VAR を含む無関係なコマンドまで止まる」に化ける。
#   そこで `if` は粗い前段フィルタとして残し、精密な判定を stdin の JSON で行う。
#
# 入力: PreToolUse の JSON を stdin で受ける（tool_input.command に Bash コマンド文字列）。
#
# exit code:
#   0: git commit でない、または検査が適合（commit を通す）
#   2: 検査違反、または前提が壊れている（commit をブロックする）
#
# exit 2 のとき Claude へ渡るのは stderr のみのため、検査の出力は >&2 で振り替える。
#
# 既知の穴: `git -C <path> commit` は `if` にも下記の判定にも一致せず素通りする。本ゲートは
# 事故を防ぐガードレールであってセキュリティ境界ではないため、意図的な回避までは塞がない。
set -uo pipefail

input=$(cat)

# コマンド文字列の抽出。jq が不在・失敗しても「対象外」へ畳まないこと。畳むと lint が
# 一度も走らないまま commit が通り、しかも警告が出ない（＝本PRが潰してきた silent
# fail-open の再生産になる）。判定不能なときは生の JSON 全体を判定対象にして fail-safe
# 側へ倒す。JSON は git commit のときだけ "git commit" を含むため、退避しても無関係な
# コマンドを巻き込まない。
# `command -v jq` の有無だけでは「jq はあるが失敗する」場合を取り逃すため、終了ステータスで分岐する。
if extracted=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null); then
    command="$extracted"
else
    command="$input"
fi

# git commit を含まないコマンドは対象外。`if` の fail-open をここで吸収する。
case "$command" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

# 検査対象のツリーを解決する。
#
# `CLAUDE_PROJECT_DIR` を無条件に使ってはならない。同変数は project root（既定のチェック
# アウト）を指すため、git worktree で作業しているセッションから commit すると、走るのは
# **コミット対象ではない別のツリー**に対する検査になる。project root が緑なら worktree の
# 変更内容と無関係に exit 0 となり、自動経路が守っているつもりで守っていない状態になる。
# 本リポジトリの作業は worktree 上で行われるため、この分岐は例外ではなく常態である。
#
# そこで「コミットが実際に走る git コンテキスト」から解決する。候補を上から順に試し、
# git のトップレベルが取れ、かつそこに runner が在る最初のものを採る。
#   1. PreToolUse の JSON が載せる cwd（ツール実行時の作業ディレクトリ）
#   2. フックプロセス自身の cwd
#   3. CLAUDE_PROJECT_DIR（従来の挙動。上2つが解決できない環境向けのフォールバック）
#
# runner の実在を条件に含めるのは、無関係なリポジトリで作業しているときに候補1・2 が
# そちらを指しても、本ゲートがその commit を巻き込んで止めないためである。
# どの候補でも解決できなければ exit 2 とする。前提が壊れているのに commit を通すと、
# 検査が一度も走らないまま素通りする（本ゲートが排してきた silent fail-open になる）。
#
# 相対パス前提の検査を含むため、解決したトップレベルへ cd してから起動する。
# glob がリポジトリルート以外で空振りすると errors=0 のまま exit 0 を返し、検査が素通りする。
json_cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)

target=""
for candidate in "$json_cwd" "$PWD" "${CLAUDE_PROJECT_DIR:-}"; do
    [ -n "$candidate" ] && [ -d "$candidate" ] || continue
    toplevel=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null) || continue
    [ -f "$toplevel/scripts/run-tests.sh" ] || continue
    target="$toplevel"
    break
done

if [ -z "$target" ]; then
    echo "pre-commit-gate: 検査対象のツリーを解決できません（runner を持つ git トップレベルが見つからない）" >&2
    echo "  試した候補: JSON の cwd / フックの cwd / CLAUDE_PROJECT_DIR" >&2
    exit 2
fi
cd "$target" || exit 2

# 全スイート runner を走らせて判定する。個々のスイートの選定と集約は runner 側の責務。
failed=0
bash scripts/run-tests.sh >&2 || failed=1

[ "$failed" -eq 0 ] || exit 2
exit 0
