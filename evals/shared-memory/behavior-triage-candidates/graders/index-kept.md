---
# 索引を消していない: 候補の表と C1 の行が残っている
type: regex
target:
  source: file
  path: global-memory/index.md
match: contains
pattern: '## 候補[\s\S]*MEM-202611150000-01'
---
