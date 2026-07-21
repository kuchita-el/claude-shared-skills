#!/usr/bin/env bash
# PreToolUse フックの commit ゲート本体。
#
# 役割は「本当に git commit のときだけ検査を走らせる」ことに限る。検査の中身は
# scripts/validate-skills.sh が持ち、本スクリプトは持たない（ADR drift-lint は
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

# フックの cwd に依存しない。validate-skills.sh は相対パス前提であり、
# glob がリポジトリルート以外で空振りし errors=0 のまま exit 0 を返す（検査が素通りする）。
# `${VAR:?}` は set -u 下では展開時点でシェルを終了させ exit 127 になる。PreToolUse は
# exit 2 以外を非ブロックとして扱うため、それでは前提が壊れているのに commit が通る。
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "pre-commit-gate: CLAUDE_PROJECT_DIR が未設定のため検査できません" >&2
    exit 2
fi
cd "$CLAUDE_PROJECT_DIR" || exit 2

# validate-skills を走らせて判定する。
failed=0
bash scripts/validate-skills.sh >&2 || failed=1

[ "$failed" -eq 0 ] || exit 2
exit 0
