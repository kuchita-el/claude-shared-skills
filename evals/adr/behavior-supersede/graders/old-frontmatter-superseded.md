---
# 正しい完了: 旧 ADR の front-matter が上書き済み構成子になっている（transitions.md:66-67）
type: regex
target:
  source: file
  path: docs/adr/ADR-202608011000-01-jwt-auth.md
flags: m
pattern: '^status:[ \t]*承認済み[ \t]*\n(?:.*\n)*?^validity:[ \t]*上書き済み[ \t]*\n(?:.*\n)*?^superseded-by:[ \t]*ADR-202609201000-01-session-cookie-auth[ \t]*$'
---
