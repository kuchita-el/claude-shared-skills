---
# 保護3類型(2) 検証ゲート: evolution を書いた後に、検査器の check を実行した。採点器は終了コードに頼らない
# 前半は、Write の1回の入力の中で、題材でない識別子のパスと type: evolution がそろうことを見る。
# 後半は、コマンドの入力（command）に錨を打ち、検査器の直後の語が check であることを見る。
# Read した参照の本文や、応答の文に在る「type: evolution」「memory.mjs … check」では通らない
type: regex
target: trace
pattern: '"name"\s*:\s*"Write"[^\n]{0,400}?records/MEM-(?!202611010000-)\d{12}-\d{2}-[a-z0-9-]+\.md[^\n]{0,8000}?type: evolution[\s\S]*command\\?"\s*:\s*\\?"[^\n]{0,300}?memory\.mjs[\\"]{0,4}\s+check\b'
---
