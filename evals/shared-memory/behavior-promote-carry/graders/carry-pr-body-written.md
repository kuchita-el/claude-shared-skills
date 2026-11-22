---
# 運ぶ経路の PR の本文（<Project の根>/tasks/promote-<新しい識別子>-pr-body.md）へ Write を呼んだ。
# 手順11で了承を文で尋ねて止まると、ここへ届かない。名前が時刻で決まるので、書いた入力を見る。
# input_match は入力の全体（content を含む）に掛かるので、file_path の値に絞る。記録の本文がこのパスに触れても通らない
type: tool_used
tool: Write
input_match: '"file_path"\s*:\s*"[^"]*docs/memory/tasks/promote-MEM-\d{12}-\d{2}-pr-body\.md"'
min: 1
---
