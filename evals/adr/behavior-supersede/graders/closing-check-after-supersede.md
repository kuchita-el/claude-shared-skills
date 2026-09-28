---
# adr-05: 旧 ADR の superseded-by を書き込んだ後に、締めの確認として旧 ADR の識別子で横断検索するか、lint の死角にある参照元（architecture.md / audit-logging）を読み直した（transitions.md:73, 185-189）
# 保護3類型(3) 完了判定の全項目確認に隣接する。付け替えを先に済ませて最後に旧 ADR を書き換える順序では、確認をせずとも通りうる（報告の懸念欄を参照）
type: regex
target: trace
pattern: 'superseded-by:[ \t]*ADR-202609201000-01-session-cookie-auth[\s\S]*(?:pattern\\?"\s*:\s*\\?"[^\n]{0,200}?(?:jwt-auth|202608011000)|file_path\\?"\s*:\s*\\?"[^\n]{0,200}?(?:architecture\.md|audit-logging))'
---
