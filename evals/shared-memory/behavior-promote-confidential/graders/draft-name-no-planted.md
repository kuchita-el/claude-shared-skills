---
# 仕込んだ文字列（リポジトリの名前・所有者）を、送り出しの下書きと報告のファイル名へ書いていない。
# ファイル名は、運ぶ手順で Global へ写り、機密の語の照合の対象でもある（confidentiality.md、outbox-report.md）。
# target: files は、その実行で作られたファイルの一覧である。文字列は scaffold.sh と同じ字面にする
type: regex
target: files
flags: im
match: not_contains
pattern: '^docs/memory/outbox/[^\n]*(?:hakobune-ledger|kumo-works)'
---
