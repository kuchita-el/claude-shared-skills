---
# 保護3類型(2) 検証ゲート: evolution を書いた後に、検査器の check を実行した。採点器は終了コードに頼らない
type: regex
target: trace
pattern: 'type: evolution[\s\S]*memory\.mjs[^\n]{0,160}check'
---
