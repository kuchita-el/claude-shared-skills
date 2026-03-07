---
description: レビュー結果をGitHubのPRにインラインコメントとして投稿
allowed-tools:
  - Bash(gh pr view *)
  - Bash(gh pr diff *)
  - Bash(gh api user *)
  - Bash(gh api repos/*/pulls/*/reviews --method POST --input *)
  - Bash(gh api repos/*/pulls/*/comments *)
  - Write
---

# PRレビューコメント投稿

レビュー結果をGitHubのPRにインラインコメントとして投稿します。

## 引数

- `$ARGUMENTS`: PRのURLまたは番号（例: `https://github.com/owner/repo/pull/123` または `123`）

## 前提条件

- `/pr-review-toolkit:review-pr` などでレビューが完了していること

## コメント内容の取得

投稿するコメント内容（ファイルパス、行番号、コメント本文）は以下の優先順位で取得する。

1. **会話コンテキストから取得**: 直前の `/pr-review-toolkit:review-pr` などでレビューした結果が会話に含まれている場合、その内容を使用する
2. **対話的に確認**: 会話にレビュー結果がない、または不明確な場合は、ユーザーに以下を確認する
   - 投稿するコメントの一覧
   - 各コメントの対象ファイルと行番号
   - コメント本文

## 手順

### 1. PR情報の取得とdiff確認（並列実行可）

以下の3つのコマンドは並列実行可能:

```bash
gh pr view {pr_number} --json headRefOid,author,url
gh pr diff {pr_number}
gh api user --jq '.login'
```

- 3つ目のコマンドで現在の認証ユーザー（自分）のログインIDを取得する

**PR情報の出力例:**

```json
{
  "headRefOid": "b1581e9f2f6970fa6fc79cdd6fb197d81d725e7a",
  "author": { "login": "username" },
  "url": "https://github.com/{owner}/{repo}/pull/{pr_number}"
}
```

- `headRefOid`: コミットSHA（`commit_id` として使用）
- `author.login`: PR作成者（自分のPRかどうかの判定に使用）
- `url`: URLから `{owner}/{repo}` を抽出してAPI呼び出しに使用

**注意**: コメントを付けられるのは、PRのdiffに含まれる行のみです。diff外の行を指定するとAPIエラーになります。

### 行番号の注意点

**重要**: レビューエージェントが報告する行番号は「ファイル全体での行番号」です。
GitHub APIでコメントできるのは「diffのhunk内に含まれる行番号」のみです。

#### diffのhunk確認方法

手順1で取得した `gh pr diff {pr_number}` の出力から、`@@` で始まる行（hunkヘッダー）を抽出する。

出力例:

```
@@ -45,8 +45,9 @@ export const serverApi = ...
```

→ この場合、RIGHTサイドは45-53行目のみにコメント可能

#### diff外の行に対する対処法

1. **近いdiff内の行にコメント**: diff内で最も関連する行にコメントし、本文で「XX行目も同様の修正が必要」と説明
2. **レビューサマリーに記載**: `body`フィールドにファイル名と行番号を含めて記載

### 2. eventパラメータの決定

`author.login` と `gh api user` の結果を比較し、自分のPRかどうかを判定する:

- **自分のPR**: `"event": "COMMENT"` を使用（`APPROVE` や `REQUEST_CHANGES` はAPIエラーになる）
- **他人のPR**: レビュー結果に応じて `APPROVE`, `REQUEST_CHANGES`, `COMMENT` から選択

### 3. コメントの投稿

以下の形式でJSONを作成し、APIを呼び出す:

```json
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT", // 手順2で決定した値を使用
  "body": "レビューサマリー",
  "comments": [
    {
      "path": "path/to/file.ts",
      "line": 47,
      "side": "RIGHT",
      "body": "コメント本文"
    }
  ]
}
```

APIを呼び出す:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --method POST --input {JSONファイルパス}
```

### 4. 投稿後の確認

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[].body'
```

## 複数行コメント

複数行にまたがるコメントを投稿する場合は、`start_line` と `start_side` を追加する:

```json
{
  "path": "path/to/file.ts",
  "start_line": 45,
  "start_side": "RIGHT",
  "line": 50,
  "side": "RIGHT",
  "body": "45〜50行目に対するコメント"
}
```

## 補足

### なぜ `line` + `side` を使うのか

| 方式            | 特徴                                                       |
| --------------- | ---------------------------------------------------------- |
| `position`      | diff内の相対位置を計算する必要があり、hunk境界でズレやすい |
| `line` + `side` | ファイルの行番号を直接指定でき、計算不要で正確             |

### よくあるエラーと対処法

| エラーメッセージ                                           | 原因                       | 対処法                        |
| ---------------------------------------------------------- | -------------------------- | ----------------------------- |
| `pull_request_review_thread.line must be part of the diff` | diff外の行を指定           | `gh pr diff` で行番号を再確認 |
| `Can not approve your own pull request`                    | 自分のPRを承認しようとした | `"event": "COMMENT"` を使用   |
| `Validation Failed`                                        | commit_idが古い            | 最新の `headRefOid` を再取得  |
