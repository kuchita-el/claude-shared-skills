---
# 観測を伴わない一般論を、関門で捨てる（SKILL.md 手順2 の関門「このタスクで観測した事実が無い」）
type: llm
---

The work memo contains a general opinion with no observation behind it: input validation should be done at an early stage. Judge only the final response text.

PASS if the final response lists this opinion as a candidate that was discarded (捨てる), with a reason saying that there is no observation in this task (観測が無い) or that it is a generality.

FAIL if the final response adds this opinion as a record, or omits it entirely, or discards it for an unrelated reason.
