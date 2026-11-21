---
description: "挙動: 作業メモの4件の学びを、足す・直す（置き換え）・捨てる（重なる／観測が無い）に分け、別の文脈での照合、下書きの後の検査、索引の作り直しを通すことを観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 60
timeout_seconds: 1200
allowed_tools:
  - Skill
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Bash(git rev-parse*)
  - Bash(git status*)
  - Bash(git log*)
  - Bash(git diff*)
  - Bash(git -C * log -1*)
  - Bash(git remote get-url *)
  - Bash(date -u*)
  - Bash(node *scripts/memory.mjs*)
---

propose-records スキルを使って、notes/task-notes.md の作業メモから、学びの候補を記録として提案して。このあと席を外すので、途中で質問はせずに最後まで進めて、判断したことは最後にまとめて報告して。
