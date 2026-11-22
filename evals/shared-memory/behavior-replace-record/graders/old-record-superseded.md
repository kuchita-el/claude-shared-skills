---
# 3つのうちの2つ目: 旧い記録が、新しい記録を superseded-by で指す
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-failed-job-retried-three-times.md
flags: m
pattern: '^superseded-by:[ \t]*MEM-\d{12}-\d{2}[ \t]*$'
---
