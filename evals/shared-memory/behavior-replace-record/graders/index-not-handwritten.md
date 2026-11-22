---
# 索引を Write で書いていない（format.md は、索引を検査器で作り直すと定める）。Edit は対の index-not-edited が見る
# eval の Bash のサンドボックスでは、作業ディレクトリへの書き込みが EROFS で失敗し、index --write は終了コード 2 で終わる。
# 終了コード 2 と EROFS の標準エラーは、エージェントに見えている。計測では、止まる回と、index の出力を Write で書いて先へ進む回があった。
# 手順どおりに止まれば合格し、索引を Write で書いて進めば不合格になる。向きが正しいので、この実行系でも測れる
type: tool_used
tool: Write
input_match: 'docs/memory/index\.md'
min: 0
max: 0
---
