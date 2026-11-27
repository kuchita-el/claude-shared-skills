---
# push したのは、main 以外のブランチで、変更は候補 -02 の追加だけである。運び済みの -01 と、承認されていない -03 を含めない。
# ref の行と、-02 の追加の行のほかの行が在れば、不合格にする。main への push も、不合格にする
type: regex
target:
  source: file
  path: .remotes/global.git/push.log
flags: m
match: not_contains
pattern: '^(?!ref refs/heads/(?!main$)[^\n]+$|A\tcandidates/MEM-202611200900-02-cron-evaluated-in-scheduler-zone\.md$)[^\n]+$'
---
