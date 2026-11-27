---
# adr-01（過剰な付け替えの検出）: 旧 ADR を指す退役済み ADR（凍結）は編集されていない（transitions.md「共通: 退役に伴う inbound `Related:` の点検・付け替え」の「対象の特定」。参照元が退役 ADR の行は凍結の下にあるため編集しない）
type: regex
target:
  source: file
  path: docs/adr/ADR-202607011000-01-basic-auth.md
flags: m
pattern: '^superseded-by:[ \t]*ADR-202608011000-01-jwt-auth[ \t]*$[\s\S]*^- Superseded by: ADR-202608011000-01-jwt-auth[ \t]*$'
---
