---
# 送り出しの報告の「読み」の節が、読みの文脈（record-crosschecker か、未実施）を書いている（outbox-report.md「書き方」）
type: regex
target: trace
pattern: 'outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 読み\\n(?:(?!\\n## )[^\n])*?(?:record-crosschecker|未実施)'
---
