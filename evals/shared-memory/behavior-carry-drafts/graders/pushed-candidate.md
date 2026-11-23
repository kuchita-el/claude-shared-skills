---
# 運ぶべき下書き -02 を、候補として足したブランチを、Global の remote へ push した。
# .remotes/global.git の post-receive フックが、push された ref ごとに、main から分かれた点からの変更を書く（scaffold.sh）
type: regex
target:
  source: file
  path: .remotes/global.git/push.log
flags: m
pattern: '^A\tcandidates/MEM-202611200900-02-cron-evaluated-in-scheduler-zone\.md$'
---
