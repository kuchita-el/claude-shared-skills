---
# 食い違う検証済みの候補を、新しい記録として足さず、置き換えとして扱う（SKILL.md 手順4 の表「食い違う記録が在り、候補が検証済み」）
type: llm
---

The workspace already has a record MEM-202611010000-02 stating that the daily report aggregation reads the input CSV as Shift_JIS. The work memo reports a verified observation that contradicts it (a Shift_JIS file is garbled, a UTF-8 file is aggregated correctly). Judge only the final response text.

PASS if the final response treats the character-encoding candidate as a fix (直す) that replaces or supersedes MEM-202611010000-02, and names MEM-202611010000-02.

FAIL if the final response treats the character-encoding candidate as a plain addition (足す) with no replacement of MEM-202611010000-02, or as discarded, or does not name MEM-202611010000-02.
