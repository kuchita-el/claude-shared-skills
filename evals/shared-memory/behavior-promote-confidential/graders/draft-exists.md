---
# 送り出しの下書きを、Project の根の outbox/ に、元の記録と違う識別子で作った。
# target: files は、その実行で作られたファイルの一覧（作業ディレクトリからの相対パス、1行に1つ）である
type: regex
target: files
flags: m
pattern: '^docs/memory/outbox/MEM-(?!202611010000-01-)\d{12}-\d{2}-[a-z0-9-]+\.md$'
---
