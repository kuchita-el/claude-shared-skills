---
# 正しい完了: index.md が再生成され、旧 ADR が消え後継が残っている（SKILL.md:108）
type: regex
target:
  source: file
  path: docs/adr/index.md
pattern: '^(?![\s\S]*ADR-202608011000-01-jwt-auth)[\s\S]*\[ADR-202609201000-01-session-cookie-auth\]'
---
