---
# 保護3類型(2) 検証ゲート: 突き合わせへ委ねる前に、根を検査した
# 採点器は Bash の終了コードに頼らない（eval の子セッションでは、成功したコマンドも 1 と表示される）
# コマンドの入力（command）に錨を打ち、検査器の直後の語が check であることを見る。Read した参照の本文や、
# 応答の文に在る「memory.mjs … check」では通らない
type: regex
target: trace
pattern: 'command\\?"\s*:\s*\\?"[^\n]{0,300}?memory\.mjs[\\"]{0,4}\s+check\b[\s\S]*"subagent_type"\s*:\s*"(?:[\w.-]+:)?record-crosschecker"'
---
