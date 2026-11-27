---
# 元の記録に、送り出した下書きの識別子を sent-as で書いた（SKILL.md 手順6）。元の記録の識別子を並べた形は通らない
type: regex
target:
  source: file
  path: docs/memory/records/MEM-202611010000-01-bom-breaks-header-match.md
flags: m
pattern: '^sent-as:[ \t]*\r?\n[ \t]+- MEM-(?!202611010000-01)\d{12}-\d{2}[ \t]*\r?$'
---
