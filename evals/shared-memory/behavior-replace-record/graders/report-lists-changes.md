---
# 出力: 変えたファイル（旧い記録・新しい記録・evolution の記録）を報告した
# 検査の結果（違反の件数）の条件は外した。この実行系では index --write が EROFS で失敗し、手順どおりなら check の前に止まる。
# 違反0件を報告できるのは、索引を手で書いた（退行した）ときだけになる（test-execution.md §7.2）
type: llm
---

Judge only the final response text.

PASS if the final response names the old record MEM-202611010000-01 as replaced, AND names (by path or identifier) a new record and an evolution record that were written.

FAIL if any of these is missing.
