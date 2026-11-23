---
description: "挙動: 作業メモの5件の学びを、足す（Project と、Global への送り出し）・直す（置き換え）・捨てる（重なる／観測が無い）に分け、別の文脈での照合、下書きの後の検査、索引の作り直し、送り出しの下書きを outbox/ に書き Global Memory の根へ書かないことを観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 80
timeout_seconds: 1800
allowed_tools:
  - Skill
  - Read
  - Write
  - Edit
  - Agent
  - Bash(git rev-parse*)
  - Bash(git status*)
  - Bash(git log*)
  - Bash(git diff*)
  - Bash(git -C * log -1*)
  - Bash(git remote get-url *)
  - Bash(git -C * remote get-url *)
  - Bash(git -C * rev-parse --show-toplevel*)
  - Bash(date -u*)
  - Bash(grep -i -F *)
  - Bash(node *scripts/memory.mjs*)
  - Bash(git -C * fetch --deepen=*)
  - Bash(git -C * status --porcelain*)
  - Bash(git -C * branch --show-current*)
  - Bash(git -C * switch --detach FETCH_HEAD)
  - Bash(git -C * switch -c carry/*)
  - Bash(git -C * add -- candidates/*)
  - Bash(git -C * ls-tree *)
---

propose-records スキルを使って、notes/task-notes.md の作業メモから、学びの候補を記録として提案して。Global Memory の根は global-memory ディレクトリ（--global-root global-memory）。このあと席を外すので、途中で質問はせずに最後まで進めて、判断したことは最後にまとめて報告して。
