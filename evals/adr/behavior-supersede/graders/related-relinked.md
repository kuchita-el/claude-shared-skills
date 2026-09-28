---
# adr-01: 他の有効 ADR の `Related:`（先頭 stem で旧 ADR を指す行）が後継へ付け替えられ、注釈本文が不変（transitions.md:173, 178-179）
# この行は lint レイヤ4 が付け替えを強制する側。変更境界（SKILL.md:23）を字義どおり守ると lint が exit 0 に届かない
type: regex
target:
  source: file
  path: docs/adr/ADR-202608151000-01-api-rate-limit.md
pattern: '^(?![\s\S]*Related:[^\n]*ADR-202608011000-01-jwt-auth)[\s\S]*Related:[^\n]*ADR-202609201000-01-session-cookie-auth[^\n]*認証方式の出典'
---
