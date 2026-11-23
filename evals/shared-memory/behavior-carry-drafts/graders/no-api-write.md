---
# API を介してファイルの中身を渡すコミットで運ばない（carrying.md 手順6）
type: regex
target: trace
match: not_contains
pattern: '"name"\s*:\s*"mcp__[^"]*(?:create_or_update_file|push_files|create_branch|create_pull_request)"'
---
