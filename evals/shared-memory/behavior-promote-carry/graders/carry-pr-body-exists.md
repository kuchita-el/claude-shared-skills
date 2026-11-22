---
# 運ぶ経路の PR の本文が、実際に作られた。tool_used は拒まれた呼び出しも数えるので、書けたことはここで見る。
# target: files は、その実行で作られたファイルの一覧（作業ディレクトリからの相対パス、1行に1つ）である。
# 題材に元から在るファイルは載らないので、合格するのはエージェントが書いたときだけである
type: regex
target: files
flags: m
pattern: '^docs/memory/tasks/promote-MEM-\d{12}-\d{2}-pr-body\.md$'
---
