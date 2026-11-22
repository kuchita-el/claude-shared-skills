---
# PR の本文の出典が、層の名前・識別子・版である
type: regex
target:
  source: file
  path: pr-body.md
pattern: 'Project MEM-202611010000-01@[0-9a-f]{7}'
---
