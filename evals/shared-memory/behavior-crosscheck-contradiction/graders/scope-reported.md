---
# 完了判定の全項目の列挙: 見た範囲と、突き合わせの文脈を、0件の項目も含めて報告した
type: llm
---

Judge only the final response text.

PASS if the final response states BOTH of the following: (1) the scope that was examined (for example the memory root, the number of index rows read, or which records were read in full), and (2) that the cross-check was performed in a separate context (a subagent / 別の文脈).

FAIL if either of the two is missing.
