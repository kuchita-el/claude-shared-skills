---
# 旧い記録の主張と本文は変えない（消さず、書き換えない）
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-failed-job-retried-three-times.md
flags: m
pattern: '^title: tokei-cron は、失敗したジョブを既定で3回まで再試行する[ \t]*$[\s\S]*ジョブは4回起動し、4回目の失敗で止まった。'
---
