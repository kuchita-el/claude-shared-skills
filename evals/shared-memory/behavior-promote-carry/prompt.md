---
description: "挙動: commit・push を許可されない非対話の実行で、了承を応答の文で尋ねずに手順11から「運ぶ経路」まで到達し、運ぶための2つのファイルを書いて報告することを確かめる。了承待ちで止まる退行の検出は主張しない（理由は scaffold.sh の冒頭）"
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
  - Bash(git -C * remote get-url *)
  - Bash(git -C * rev-parse --verify *)
  - Bash(git -C * rev-parse --show-toplevel*)
  - Bash(mktemp -d*)
  - Bash(grep -i -F *)
---

promote-record スキルで、記録 MEM-202611010000-01 を、Global Memory へ昇格して。元の記録は、このリポジトリの Project Memory（docs/memory）に在る。昇格先の根は global-memory ディレクトリ（--global-root global-memory）。
