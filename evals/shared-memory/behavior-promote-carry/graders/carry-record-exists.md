---
# 運ぶ経路の記録が、実際に作られた。PR の本文のファイルは除く。PR の本文だけを書く退行を、ここで不合格にする
type: regex
target: files
flags: m
pattern: '^docs/memory/tasks/promote-MEM-\d{12}-\d{2}-(?!pr-body\.md)[a-z0-9-]+\.md$'
---
