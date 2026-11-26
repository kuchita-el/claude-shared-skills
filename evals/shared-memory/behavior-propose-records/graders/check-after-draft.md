---
# 保護3類型(2) 検証ゲート: 新しい記録を書いた後に、check が走った（SKILL.md 手順6「Project の根に行う」）
# 下書きの前にだけ check が走った場合を、ここで落とす。題材の記録（MEM-202611010000-…）のパスは、
# 下書きの前から trace に出る。Write の入力に在る、題材でない識別子のパスだけを、下書きとして数える。check はコマンドの入力（command）に錨を打って見る。最終の応答に書いたコマンドの文字列では通らない
type: regex
target: trace
pattern: '"name"\s*:\s*"Write"[^\n]{0,400}?records/MEM-(?!202611010000-)\d{12}-\d{2}-[a-z0-9-]+\.md[\s\S]*command\\?"\s*:\s*\\?"[^\n]{0,300}?memory\.mjs[\\"]{0,4}\s+check\b'
---
