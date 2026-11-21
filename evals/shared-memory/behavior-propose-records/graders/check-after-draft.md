---
# 保護3類型(2) 検証ゲート: 新しい記録を書いた後に、check が走った（SKILL.md 手順6「下書きを置いた根ごとに行う」）
# 下書きの前にだけ check が走った場合を、ここで落とす
type: regex
target: trace
pattern: 'records/MEM-\d{12}-\d{2}-[a-z0-9-]+\.md[\s\S]*memory\.mjs[^\n]{0,40}check'
---
