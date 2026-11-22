---
# 過剰な置き換えの検出: 重なるだけの記録 X は、置き換え済みになっていない
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-empty-input-zero-report.md
pattern: '^(?![\s\S]*superseded-by:)[\s\S]*id: MEM-202611010000-01'
---
