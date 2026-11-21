---
# 昇格先の索引を書かない（題材の利用規則は、索引を PR に含めないと定める）: 索引の記録の行が1件のままである
type: regex
target:
  source: file
  path: global-memory/index.md
match: not_contains
pattern: '\| \[MEM-[\s\S]*\| \[MEM-'
---
