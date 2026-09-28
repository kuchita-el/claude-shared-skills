---
type: tool_used
tool: Agent
input_match: '"subagent_type"\s*:\s*"(?:[\w.-]+:)?doc-writer"'
min: 1
---

狙う所見: 正しい完了。起草工程が doc-writer サブエージェントへ委譲されたことを確認する。
根拠: plugins/writing/skills/write-doc/SKILL.md:48「入力を正規化し...doc-writerへ渡す」。
