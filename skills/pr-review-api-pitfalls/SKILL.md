---
description: GitHub Pull Request Reviews APIの落とし穴と回避策（line/side指定、diff hunk制約、自己PRレビュー制限、複数行コメント）。gh apiでPRにレビューコメントやインラインコメントを投稿するとき、PRレビュー投稿でAPIエラーが発生したときに参照。
user-invocable: false
---

## PRレビューコメント投稿の落とし穴

### line + side を使う（position は使わない）

`position`（diff内の相対位置）はhunk境界でズレやすい。`line`（ファイルの行番号）+ `side`（`RIGHT`）を直接指定する。

### コメントできるのはdiff hunk内の行のみ

diff外の行を指定すると `pull_request_review_thread.line must be part of the diff` エラーになる。

**回避策:**
- diff内で最も関連する行にコメントし、本文で「XX行目も同様の修正が必要」と説明
- レビューサマリー（`body`フィールド）にファイル名と行番号を含めて記載

### 自分のPRには APPROVE / REQUEST_CHANGES を使えない

`Can not approve your own pull request` エラーになる。自分のPRには `"event": "COMMENT"` を使用する。
他人のPRではレビュー結果に応じて `APPROVE`, `REQUEST_CHANGES`, `COMMENT` から選択する。

### 複数行コメント

`start_line` + `start_side` を追加する。

### よくあるエラー

| エラーメッセージ | 原因 | 対処法 |
|---|---|---|
| `pull_request_review_thread.line must be part of the diff` | diff外の行を指定 | `gh pr diff` で行番号を再確認 |
| `Can not approve your own pull request` | 自分のPRを承認しようとした | `"event": "COMMENT"` を使用 |
| `Validation Failed` | commit_idが古い | 最新の `headRefOid` を再取得 |
