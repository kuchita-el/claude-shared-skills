---
# 正しい完了: 旧 ADR 本文 `## 関連ADR` に `Superseded by:` が追記されている（transitions.md:70-71。lint が素通りする項目）
type: regex
target:
  source: file
  path: docs/adr/ADR-202608011000-01-jwt-auth.md
flags: m
pattern: '^[ \t]*-[ \t]*Superseded by:[ \t]*ADR-202609201000-01-session-cookie-auth[ \t]*$'
---
