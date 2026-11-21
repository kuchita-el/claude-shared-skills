---
# 保護3類型(2) 検証ゲート: 突き合わせへ委ねる前に、根を検査した
# 採点器は Bash の終了コードに頼らない（eval の子セッションでは、成功したコマンドも 1 と表示される）
type: regex
target: trace
pattern: 'memory\.mjs[^\n]{0,120}check[\s\S]*"subagent_type"\s*:\s*"(?:[\w.-]+:)?record-crosschecker"'
---
