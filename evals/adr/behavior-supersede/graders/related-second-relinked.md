---
# adr-01 / adr-05: 1行に複数 ADR を列挙した `Related:` の2件目で旧 ADR を指す参照が解消されている（transitions.md「共通: 退役に伴う inbound `Related:` の点検・付け替え」の「2件目以降の列挙は人手で確かめる」「締めの確認」）
# lint は先頭の full slug しか見ないため exit 0 に現れない。締めの確認の2点目でのみ拾える
type: regex
target:
  source: file
  path: docs/adr/ADR-202608201000-01-audit-logging.md
pattern: '^(?![\s\S]*Related:[^\n]*ADR-202608011000-01-jwt-auth)[\s\S]*Related:[^\n]*ADR-202609201000-01-session-cookie-auth'
---
