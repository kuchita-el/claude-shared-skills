---
# 書き込みの試みの観測（採点外）。commit・checkout・switch・push・gh pr の呼び出しを試みたかを数える。
# tool_used は拒まれた呼び出しも数える。題材の許可は git の書き込みを持たないので、試みれば確認なしモードで拒まれる。
# 不合格は、書き込みの型の呼び出しが無かったことだけを表す。調べるコマンド（git -C global-memory status 等）が
# 拒まれた段で運ぶ経路へ進んだ回も不合格になり、その回も許可を尋ねられない状態には入っている。不合格が想定される観測である。
# 「採点外」は skill-fired と同じく読む側の約束であり、eval の実行系はこの採点器も点に数える
type: tool_used
tool: Bash
input_match: 'git (?:-C \S+ )?(?:checkout|switch|commit|push)|gh pr '
min: 1
---
