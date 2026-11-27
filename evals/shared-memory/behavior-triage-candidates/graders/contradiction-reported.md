---
# 食い違う候補（C2）が、既存の記録（R2）と食い違うと報告されている
type: llm
---

The candidate MEM-202611150000-02 says to put a linter into pre-commit from the start. The existing record MEM-202611010000-02 says to put it in CI as warnings first. Judge only the final response text.

PASS if the final response reports that MEM-202611150000-02 contradicts (食い違う) MEM-202611010000-02, and does not propose 採る for MEM-202611150000-02 without noting the contradiction.

FAIL if the final response does not report that contradiction.
