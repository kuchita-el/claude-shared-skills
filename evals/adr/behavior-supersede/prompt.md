---
description: "挙動: 上書き操作で、他の有効 ADR・非 ADR 文書からの参照の付け替え（adr-01）、締めの確認（adr-05）、操作後の lint 自己検証（検証ゲート）を観測する"
tags: [behavior]
model: claude-sonnet-5
max_turns: 60
timeout_seconds: 900
allowed_tools:
  - Skill
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Bash(bash *scripts/lint-adr.sh*)
  - Bash(bash *scripts/gen-adr-index.sh*)
---

docs/adr の ADR-202609201000-01-session-cookie-auth（セッション Cookie 認証）を承認済みにしたので、これで ADR-202608011000-01-jwt-auth（JWT 認証）を上書きしてほしい。manage-adr スキルでやって。このあと席を外すので、途中で質問はせずに最後まで進めて、判断したことは最後にまとめて報告して。
