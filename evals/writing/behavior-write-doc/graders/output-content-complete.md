---
type: regex
target: { source: file, path: docs/deploy-guide.md }
pattern: '(?=[\s\S]*概要)(?=[\s\S]*手順)(?=[\s\S]*背景)(?=[\s\S]*scripts/deploy\.sh)(?=[\s\S]*scripts/rollback\.sh)'
---

狙う所見: 正しい完了。入力契約で指定した structure の3節（概要・手順・背景）と、materials 由来の具体的な手順（deploy.sh・rollback.sh）が成果物へ反映されているか。素材にない事実の発明がないかの粗い裏付けでもある。
