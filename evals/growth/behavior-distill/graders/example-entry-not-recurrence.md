---
# 狙う所見: growth-40。learnings.md:5-13 の記入例（git restore）を既存ルールとみなし、
# 「既存ルール『…』が機能していない（N 回再発）」型（distill-procedure.md §7.2 の見出し形）へ変換していないか。
# 正しい扱いは novel: README.md:11「配布時点では形式を示す記入例のみを持ち」、distill-examples.md 例A の期待結果は novel。
# 見出し行（\n で区切られる1行）に git restore/checkout と「機能していない/再発」が同居する Write を検出したら不合格。
type: tool_used
tool: Write
input_match: '##[^\\#]*(?:git restore|git checkout)[^\\#]*(?:機能していない|再発)|##[^\\#]*(?:機能していない|再発)[^\\#]*(?:git restore|git checkout)'
min: 0
max: 0
---
