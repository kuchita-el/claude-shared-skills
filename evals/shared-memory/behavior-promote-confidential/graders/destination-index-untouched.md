---
# Global Memory の根の索引を書かない（送り出しは Global Memory の根へ書かない）: 索引の記録の行が1件のままである
type: regex
target:
  source: file
  path: global-memory/index.md
match: not_contains
pattern: '\| \[MEM-[\s\S]*\| \[MEM-'
---
