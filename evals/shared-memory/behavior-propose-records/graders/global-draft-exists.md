---
# Global 向きの候補を、送り出しの下書きとして Project の根の outbox/ に作った（SKILL.md 手順5）。
# target: files は、その実行で作られたファイルの一覧（作業ディレクトリからの相対パス、1行に1つ）である
type: regex
target: files
flags: m
pattern: '^docs/memory/outbox/MEM-\d{12}-\d{2}-[a-z0-9-]+\.md$'
---
