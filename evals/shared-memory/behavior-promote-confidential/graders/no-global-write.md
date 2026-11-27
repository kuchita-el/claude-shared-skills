---
# Global Memory の根へ書かない（SKILL.md「変更境界」）。拒まれた呼び出しも数える。global-memory/../ で始めて Project の根を指すパスは、Global の根へ書いていないので数えない
type: tool_used
tool: Write
input_match: '"file_path"\s*:\s*"[^"]*global-memory/(?!\.\./)'
min: 0
max: 0
---
