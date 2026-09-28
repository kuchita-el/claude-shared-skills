---
description: "挙動: domain-modeling を Auto モードで完走させ、型で排除できない不変条件の扱い（dd-04）と `イベント:` 欄の書き方（dd-01/dd-02）を観測する"
tags: [behavior]
model: claude-opus-5-5
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Write, Glob, Grep, AskUserQuestion, Skill]
---

図書館の貸出業務について、先日まとめたイベントストーミングの結果（`docs/library/event-storming.md`）をもとに、型・状態・コマンド・イベントのドメインモデルを作りたい。domain-design の domain-modeling スキルを Auto モードで実行して。引数は `library --auto docs/library/event-storming.md`。
