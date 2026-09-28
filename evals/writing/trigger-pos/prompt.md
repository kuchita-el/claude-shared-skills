---
description: "正例: 素材付きの文書起草依頼で write-doc が起動する"
tags: [trigger]
model: claude-sonnet-5
max_turns: 3
allowed_tools: [Read, Glob, Grep, Skill]
---

次の確定済み素材から、利用者向けの導入手順書を docs/guide.md に起草して。素材: (1) mise install で bats を導入する (2) bash scripts/run-tests.sh で全検査を実行する (3) 失敗時は出力末尾のスイート名を確認する。読者は初めて参加する開発者。
