---
# 送り出しの下書きに、送り出しの報告（outbox/reports/<下書きの識別子>.md）を添えた（SKILL.md 手順7）
type: regex
target: files
flags: m
pattern: '^(?=[\s\S]*^docs/memory/outbox/reports/(MEM-\d{12}-\d{2})\.md$)(?=[\s\S]*^docs/memory/outbox/\1-[a-z0-9-]+\.md$)'
---
