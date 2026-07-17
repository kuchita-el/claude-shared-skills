#!/usr/bin/env bash
# PreToolUse フックの commit ゲート本体。
#
# 役割は「本当に git commit のときだけ lint を走らせる」ことに限る。検査の中身は
# scripts/lint-adr.sh / scripts/validate-skills.sh が持ち、本スクリプトは持たない。
#
# なぜ settings.json の `if` だけでは足りないか:
#   `if` は permission rule 構文でコマンドを絞るが、コマンド名より多くを指定した
#   パターン（`Bash(git commit:*)` 等）は $()・バッククォート・$VAR を含むコマンドに
#   対して fail-open で発火する。ゲートは exit 2 でブロックするため、この誤発火は
#   「ADR が違反状態の間、$VAR を含む無関係なコマンドまで止まる」に化ける。
#   そこで `if` は粗い前段フィルタとして残し、精密な判定を stdin の JSON で行う。
#
# 入力: PreToolUse の JSON を stdin で受ける（tool_input.command に Bash コマンド文字列）。
#
# exit code:
#   0: git commit でない、または全 lint が適合（commit を通す）
#   2: lint 違反、または前提が壊れている（commit をブロックする）
#
# exit 2 のとき Claude へ渡るのは stderr のみのため、各 lint の出力は >&2 で振り替える。
set -uo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# git commit を含まないコマンドは対象外。`if` の fail-open をここで吸収する。
case "$command" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

# フックの cwd に依存しない。両 lint とも相対パス前提であり、とくに validate-skills.sh は
# glob がリポジトリルート以外で空振りし errors=0 のまま exit 0 を返す（検査が素通りする）。
cd "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR が未設定}" || exit 2

# 片方が落ちても両方走らせてから判定する（lint-adr.sh の「全違反を列挙してから
# 非0 exit する」方針に合わせ、1回の commit で全ての違反を見せる）。
failed=0
bash scripts/lint-adr.sh >&2 || failed=1
bash scripts/validate-skills.sh >&2 || failed=1

[ "$failed" -eq 0 ] || exit 2
exit 0
