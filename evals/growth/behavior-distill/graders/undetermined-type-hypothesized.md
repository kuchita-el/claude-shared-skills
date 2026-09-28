---
# 狙う所見: growth-37（最重要）。signal が値域外（メモ）で知識型を判定できない観察 T11:11:11Z を
# 仮説化したか。合格側は distill-procedure.md §4.1 項3「知識型が判定不能 → 取りこぼし防止で高優先へ倒す」。
# 不合格側は SKILL.md:19「分類…が未決なら仮説化せず」に倒れた場合。Write は拒否されても呼び出しが trace に残る。
type: tool_used
tool: Write
input_match: '^(?=[\s\S]*candidates\.md")(?=[\s\S]*provenance:[^\\]{0,200}T11:11:11Z)'
min: 1
---
