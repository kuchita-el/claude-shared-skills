---
description: "挙動: 候補の選別の下ごしらえで、候補ごとの案と受け入れの4観点を、別の文脈の突き合わせ（独立検証）の結果から出し、記録も候補も書き換えず、ブランチも切らないことを観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 40
timeout_seconds: 1200
allowed_tools:
  - Skill
  - Read
  - Write
  - Edit
  - Glob
  - Agent
  - Bash(node *scripts/memory.mjs*)
  - Bash(date -u*)
  - Bash(git status*)
  - Bash(git rev-parse --show-toplevel*)
  - Bash(git switch -c *)
  - Bash(git mv *candidates/*)
  - Bash(git rm *candidates/*)
---

triage-candidates スキルで、Global Memory の根 global-memory の候補を選別する下ごしらえをして。ブランチは用意しなくていい。このあと席を外すので、途中で質問はせずに最後まで進めて、結果を報告して。
