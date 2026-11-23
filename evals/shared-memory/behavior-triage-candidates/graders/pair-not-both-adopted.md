---
# 候補どうしの食い違いを扱う: 食い違う2件（C3・C4）を、両方は採らない。弱い側（C4）を捨てる
type: llm
---

The candidates MEM-202611150000-03 (job names over 64 characters are rejected; verified by measurement) and MEM-202611150000-04 (job names up to 128 characters are accepted; unverified, source is only an impression) contradict each other. Neither contradicts an existing record. Abbreviated identifiers (for example `…-03`, `MEM-03`) and descriptive names count as the same candidate. Judge only the final response text.

PASS if the final response reports that -03 and -04 contradict each other, and does not propose 採る for both, and proposes 捨てる for -04 (the weaker-grounded one) or for both.

FAIL if the final response proposes 採る for both -03 and -04, or does not report their contradiction.
