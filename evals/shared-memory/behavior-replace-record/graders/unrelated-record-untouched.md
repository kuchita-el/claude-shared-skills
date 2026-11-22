---
# 渡された記録のほかの記録を書き換えない
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-02-job-log-kept-thirty-days.md
flags: m
pattern: '^updated: 2026-11-01[ \t]*$'
---
