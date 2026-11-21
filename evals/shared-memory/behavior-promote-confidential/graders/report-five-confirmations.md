---
# 最終の応答が、5つの確認の結果と、突き合わせの文脈を示す
type: llm
---

Judge only the final response text.

PASS if the final response shows the results of all five promotion checks (元の経験は検証済みか / 他のプロジェクトにも当てはまるか / 適用条件と例外は何か / 機密の情報を含まないか / 既存の記録と矛盾しないか) AND states whether the cross-check ran in a separate context (別の文脈) or was not performed.

FAIL if any of the five checks is missing from the final response, or the context of the cross-check is not stated.
