---
# 運ぶ経路の記録（<Project の根>/tasks/promote-<新しい識別子>-<名前>.md）へ Write を呼んだ。PR の本文のファイルは除く。
# input_match は入力の全体（content を含む）に掛かるので、file_path の値に絞る。PR の本文がこのパスに触れても通らない
type: tool_used
tool: Write
input_match: '"file_path"\s*:\s*"[^"]*docs/memory/tasks/promote-MEM-\d{12}-\d{2}-(?!pr-body\.md)[a-z0-9-]+\.md"'
min: 1
---
