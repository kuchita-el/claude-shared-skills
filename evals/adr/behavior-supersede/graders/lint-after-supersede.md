---
# 保護3類型(2) 検証ゲート: 旧 ADR の superseded-by を書き込んだ後に lint-adr.sh を実行した（SKILL.md:104-110「各操作の完了後」）
# 観察用: adr-03（経緯段落が操作前の baseline 確認を誘発しうる）で、lint が操作前だけに走った場合をここで落とす
type: regex
target: trace
pattern: 'superseded-by:[ \t]*ADR-202609201000-01-session-cookie-auth[\s\S]*command\\?"\s*:\s*\\?"[^\n]{0,300}?lint-adr\.sh'
---
