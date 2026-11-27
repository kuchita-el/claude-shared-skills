---
# Project を取り直した（carrying.md 手順2）。題材は FETCH_HEAD を持たないので、取り直さなければ carry は止まる。-C には、根（docs/memory）かそれを含むリポジトリの最上位のどちらを渡してもよい。Global の取り直しは数えない
type: tool_used
tool: Bash
input_match: 'git -C (?!\S*global-memory)\S+ fetch --deepen=\d+ origin main'
min: 1
---
