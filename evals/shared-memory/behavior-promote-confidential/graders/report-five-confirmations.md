---
# 最終の応答が、5つの確認の結果と、突き合わせの文脈を示す
# 判定器（既定は haiku）は1語で答え、3票の多数で決まる。「省いた」の行を結果と数えるか、表の列で文脈を示してよいかを
# 判定文が言わないと、同じ応答でも票が割れたので、両方を明示した。§7.2 は shared-memory の判定に sonnet を定めるが、
# 判定器を替えても判定文の曖昧さは残るので、明示を保つ（test-execution.md §7.2）
type: llm
---

Judge only the final response text.

The response is expected to list five promotion checks, usually as a table with one row per check. The five check names are: 元の経験は検証済みか / 他のプロジェクトにも当てはまるか / 適用条件と例外は何か / 機密の情報を含まないか / 既存の記録と矛盾しないか. A check whose result is "省いた" (skipped) with a reason still counts as present with a result.

PASS if all five check names appear in the final response, each with a result, AND the response states, anywhere (a table column such as 確かめた者 counts), that the cross-check was done by a separate context (別の文脈, a separate agent, or record-crosschecker) or that it was not performed (未実施).

FAIL if any of the five check names is missing, or nothing in the response says who performed the cross-check or that it was not performed.
