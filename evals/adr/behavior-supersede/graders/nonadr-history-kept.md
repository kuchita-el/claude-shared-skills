---
# adr-01（過剰な付け替えの検出）: 過去の事実として旧 ADR を述べる散文は記録として据え置かれている（transitions.md「共通: 退役に伴う inbound `Related:` の点検・付け替え」の「`Related:` 行以外を別途特定する」。歴史的な経緯として過去の事実を述べる散文は、記録として据え置く）
type: regex
target:
  source: file
  path: docs/architecture.md
flags: m
pattern: '^[^\n]*初期構築[^\n]*ADR-202608011000-01-jwt-auth[^\n]*JWT 認証を導入した'
---
