---
description: "挙動: distill の分岐点（知識型不明の観察・learnings.md 記入例との突合・痕跡種別の順位利用・経年削除の対象選別）を通す基準値ケース。狙う所見 growth-37 / 40 / 01、観測のみ growth-32 / 07 / 08"
tags: [behavior]
model: claude-opus-5-5
max_turns: 40
timeout_seconds: 900
allowed_tools: [Skill, Read, Glob, Write, "Bash(git rev-parse *)", "Bash(date *)", "Bash(rm ~/.claude/projects/*/growth/captures-*.md)"]
---

growth の distill を回して。前回の distill 以降にたまった生観察を仮説にまとめて、candidates に入れておいてほしい。
