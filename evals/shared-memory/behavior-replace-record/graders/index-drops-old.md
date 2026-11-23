---
# 索引から旧い記録が消え、無関係の記録が残り、evolution の行が在る
type: regex
target:
  source: file
  path: docs/memory/index.md
pattern: '^(?![\s\S]*\| \[MEM-202611010000-01\])(?=[\s\S]*\| \[MEM-202611010000-02\])[\s\S]*\| evolution \|'
---
