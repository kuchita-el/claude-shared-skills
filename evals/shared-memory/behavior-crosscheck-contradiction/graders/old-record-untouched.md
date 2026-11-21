---
# 報告だけで、直さない: 食い違う相手の記録（R1）を置き換え済みにしていない
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-cron-evaluated-in-utc.md
flags: m
match: not_contains
pattern: '^(?:superseded-by|moved-to):'
---
