---
# 最終の応答が、運ぶための2つのファイル（PR の本文と記録）を名指す（SKILL.md「出力」の「出した先」）
type: regex
target: last_message
pattern: '^(?=[\s\S]*promote-MEM-\d{12}-\d{2}-pr-body\.md)(?=[\s\S]*promote-MEM-\d{12}-\d{2}-(?!pr-body\.md)[a-z0-9-]+\.md)'
---
