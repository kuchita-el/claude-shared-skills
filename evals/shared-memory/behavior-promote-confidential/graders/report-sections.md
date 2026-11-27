---
# 送り出しの報告に、outbox-report.md の5つの節（下書き・元の記録・語の照合・読み・重なりの照合）を、全て書いた。
# 報告は何度かに分けて書くので、報告のパスへの Write の content と Edit の new_string の全体を trace で見る
type: regex
target: trace
pattern: '^(?=[\s\S]*outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 下書き)(?=[\s\S]*outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 元の記録)(?=[\s\S]*outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 語の照合)(?=[\s\S]*outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 読み)(?=[\s\S]*outbox/reports/MEM-\d{12}-\d{2}\.md"[^\n]*## 重なりの照合)'
---
