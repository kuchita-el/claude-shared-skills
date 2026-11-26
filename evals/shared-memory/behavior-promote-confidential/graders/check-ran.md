---
# 保護3類型(2) 検証ゲート: 下書きを書いた後に、Project の根の check が走った（SKILL.md 手順6）。手順1 の check だけでは通らない。
# 下書きは outbox/ の直下の名前つきのファイルで、報告（outbox/reports/）と元の記録（records/）は数えない。Write の入力に在る下書きのパスの後に、check が来る順を見る
type: regex
target: trace
pattern: '"name"\s*:\s*"Write"[^\n]{0,400}?outbox/MEM-(?!202611010000-)\d{12}-\d{2}-[a-z0-9-]+\.md[\s\S]*memory\.mjs[^\n]{0,160}check[^\n]{0,160}docs/memory'
---
