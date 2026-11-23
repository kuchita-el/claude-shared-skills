---
# 完了の条件「案が出る」: 案の表に、3件の候補の全てが、5つの案のどれかとともに載っている
type: llm
---

The workspace holds a Global Memory root with three candidates: MEM-202611150000-01, MEM-202611150000-02 and MEM-202611150000-03. Judge only the final response text.

PASS if the final response has a table of proposals in which each of the three candidates has its own row, and each row carries exactly one of the five proposals: 採る, まとめる, 捨てる, 補う, 置き換える.

FAIL if any candidate has no row, or a row carries no proposal or a proposal other than the five.
