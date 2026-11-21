---
description: "挙動: 食い違う記録の組を、別の文脈の突き合わせ（独立検証）が報告し、両立する記録を食い違いに挙げず、記録も索引も書き換えないことを観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 40
timeout_seconds: 1200
allowed_tools:
  - Skill
  - Read
  - Glob
  - Write
  - Edit
  - Agent
  - Bash(node *scripts/memory.mjs*)
  - Bash(git rev-parse*)
---

crosscheck-records スキルで、docs/memory/records/MEM-202611020000-01-cron-evaluated-in-local-time.md を、既に在る記録と突き合わせて。このあと席を外すので、途中で質問はせずに最後まで進めて、結果を報告して。
