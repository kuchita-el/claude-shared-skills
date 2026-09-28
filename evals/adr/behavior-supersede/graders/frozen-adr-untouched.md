---
# adr-01（過剰な付け替えの検出）: 旧 ADR を指す退役済み ADR（凍結）は編集されていない（transitions.md:178「参照元が上書き済み / 廃止済みの行は凍結原則により編集しない」）
type: regex
target:
  source: file
  path: docs/adr/ADR-202607011000-01-basic-auth.md
flags: m
pattern: '^superseded-by:[ \t]*ADR-202608011000-01-jwt-auth[ \t]*$[\s\S]*^- Superseded by: ADR-202608011000-01-jwt-auth[ \t]*$'
---
