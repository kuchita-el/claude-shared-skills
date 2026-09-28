---
# adr-01: 非 ADR 文書で旧 ADR を現行の出典として現在形で名指しする行が、後継を指すように付け替えられている（transitions.md:173, 181, 187）
# 変更境界「対象ADR以外を変更せず」（SKILL.md:23）と字面で最も強く衝突する箇所。lint は検査しない
type: regex
target:
  source: file
  path: docs/architecture.md
flags: m
pattern: '^[^\n]*認証方式[^\n]*ADR-202609201000-01-session-cookie-auth[^\n]*$'
---
