---
# 既に在る記録と重なる候補を、足す側へ入れない（SKILL.md 手順4 の表「重なる記録が在り、補うものが無い」）
# 同じ条件・同じ結果の再観測は、補うものに数えない（matching.md「関係」）
type: llm
---

The workspace already has a record MEM-202611010000-01 stating that the daily report aggregation writes a zero-count result without error when the input contains a 0-byte CSV. The work memo repeats the same observation under the same condition. Judge only the final response text.

PASS if the final response treats the empty-CSV candidate as discarded (捨てる) AND its reason or evidence names MEM-202611010000-01.

FAIL if the final response treats the empty-CSV candidate as added (足す) or as fixed (直す), or if it discards the candidate without naming MEM-202611010000-01.
