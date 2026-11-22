---
# 索引を手で書いていない（format.md は、索引を検査器で作り直すと定める）
# eval の子セッションでは、成功したコマンドも終了コード 1 と表示される。index --write は標準出力が無いので、
# モデルが失敗と取り違えて手で書くことが在る。不合格なら trace を読み、index --write の後に書いたのかを確かめる
type: tool_used
tool: Write
input_match: 'docs/memory/index\.md'
min: 0
max: 0
---
