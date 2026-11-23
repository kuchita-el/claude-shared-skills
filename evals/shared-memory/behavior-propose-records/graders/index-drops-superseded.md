---
# 正しい完了: 作り直した索引から、置き換え済みの Y の行が消え、X の行が残っている
type: regex
target:
  source: file
  path: docs/memory/index.md
pattern: '^(?![\s\S]*\| \[MEM-202611010000-02\])[\s\S]*\| \[MEM-202611010000-01\]'
---
