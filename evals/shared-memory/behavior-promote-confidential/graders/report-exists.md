---
# 送り出しの報告を、outbox/reports/<下書きの識別子>.md に作った。報告の識別子と同じ識別子の下書きも、作られている
type: regex
target: files
flags: m
pattern: '^(?=[\s\S]*^docs/memory/outbox/reports/(MEM-\d{12}-\d{2})\.md$)(?=[\s\S]*^docs/memory/outbox/\1-[a-z0-9-]+\.md$)'
---
