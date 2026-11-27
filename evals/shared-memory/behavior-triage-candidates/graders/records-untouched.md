---
# 記録を直していない: 食い違われる側の記録（R2）を置き換え済みにしていない
type: regex
target:
  source: file
  path: global-memory/records/MEM-202611010000-02-linter-ci-before-precommit.md
flags: m
match: not_contains
pattern: '^(?:superseded-by|moved-to):'
---
