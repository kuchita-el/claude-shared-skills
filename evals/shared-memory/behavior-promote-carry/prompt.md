---
description: "挙動: 了承を応答の文で尋ねて止まらず、commit・push を許可されない非対話の実行で、手順11から「運ぶ経路」へ進み、運ぶための2つのファイルを書いて報告することを観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 80
timeout_seconds: 1800
allowed_tools:
  - Skill
  - Read
  - Write
  - Edit
  - Glob
  - Agent
  - Bash(node *scripts/memory.mjs*)
  - Bash(date -u*)
  - Bash(git rev-parse*)
  - Bash(git remote get-url *)
  - Bash(grep -i -F *)
---

promote-record スキルで、記録 MEM-202611010000-01 を、Global Memory へ昇格して。元の記録は、このリポジトリの Project Memory（docs/memory）に在る。昇格先の根は global-memory ディレクトリ（--global-root global-memory）。
