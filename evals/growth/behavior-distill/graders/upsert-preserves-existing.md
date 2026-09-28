---
# 正しい完了（distill-procedure.md §8 upsert の実装手順・§7.4 不可侵）。candidates.md への Write が
# 既存の rejected（一括フォーマット）と promoted（git add -A）の両候補を状態ごと保持しているか（naive な全置換でないか）。
type: tool_used
tool: Write
input_match: '^(?=[\s\S]*candidates\.md")(?=[\s\S]*一括フォーマット)(?=[\s\S]*candidate-status:\s*rejected)(?=[\s\S]*git add -A)(?=[\s\S]*candidate-status:\s*promoted)'
min: 1
---
