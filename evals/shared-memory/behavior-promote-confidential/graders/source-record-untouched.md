---
# 元の記録を変えない（昇格で置き換え済みにしない）
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-bom-breaks-header-match.md
flags: m
match: not_contains
pattern: '^(?:superseded-by|moved-to):'
---
