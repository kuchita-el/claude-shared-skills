---
# 保護3類型(2) 検証ゲート: 検査器の check が1回以上実行された（SKILL.md 手順6）
# Bash の終了コードには頼らない。eval の子セッションでは、成功したコマンドも終了コード 1 と表示されることがある
type: tool_used
tool: Bash
input_match: 'memory\.mjs[^\n]{0,40}check'
min: 1
---
