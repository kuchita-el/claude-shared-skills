---
type: tool_used
tool: Agent
input_match: '"subagent_type"\s*:\s*"(?:[\w.-]+:)?doc-reviewer"'
min: 1
---

狙う所見: 保護3類型の(1) 別文脈が初見でレビューする独立検証。将来の除去作業でこの独立レビューが落ちていないかを検出する番人。
根拠: plugins/writing/skills/write-doc/SKILL.md:63-69「独立レビュー」節（素材・起草経緯・writerの判断を渡さない旨も含む）。plugins/writing/agents/doc-reviewer.md:11-25「入力」節は、入力を6つだけに限定する。6つは、対象文書・読み手・文書種別・文書種別profileのpath・共通規約のpath・plugin root pathである。
