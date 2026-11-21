---
# 無かった根を、出力に示す（SKILL.md「出力」の「無かった根」）。付け忘れに気づけるようにするためである
type: llm
---

The workspace has a Project Memory root (docs/memory) and no Global Memory. Judge only the final response text.

PASS if the final response states that Global Memory is absent or not attached, or that no matching was done against Global Memory.

FAIL if the final response does not mention the absence of Global Memory at all, or claims that Global Memory was checked.
