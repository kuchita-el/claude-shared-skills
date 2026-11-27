---
# 元の記録を置き換え済みにしない（送り出しで変えるのは sent-as だけである）
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-bom-breaks-header-match.md
flags: m
match: not_contains
pattern: '^(?:superseded-by|moved-to):'
---
