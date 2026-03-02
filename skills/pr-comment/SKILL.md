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

```bash
gh pr diff {pr_number} | grep "^@@"
```

出力例:

```
@@ -45,8 +45,9 @@ export const serverApi = ...
```

→ この場合、RIGHTサイドは45-53行目のみにコメント可能

#### diff外の行に対する対処法

1. **近いdiff内の行にコメント**: diff内で最も関連する行にコメントし、本文で「XX行目も同様の修正が必要」と説明
2. **レビューサマリーに記載**: `body`フィールドにファイル名と行番号を含めて記載

### コメント作成前のチェックリスト

- [ ] 各コメントの`line`がdiffのhunk範囲内か確認
- [ ] `side: "LEFT"`を使う場合、その行が削除された行か確認
- [ ] diff外の行への指摘は、近いdiff内の行またはサマリーに記載

### 2. eventパラメータの決定

手順1で取得した情報を使って、`event`パラメータを決定する:

1. **PR作成者の判定**: `author.login` と 現在のユーザー（`gh api user`の結果）を比較
2. **eventの決定**:
   - **自分のPR**（author.login = 現在のユーザー）: `"event": "COMMENT"` を使用（必須）
   - **他人のPR**: レビュー結果に応じて `APPROVE`, `REQUEST_CHANGES`, `COMMENT` から選択

**重要**: 自分のPRに対して `APPROVE` や `REQUEST_CHANGES` を使用するとAPIエラーになります。

### 3. コメントの投稿

**手順**: Write ツールで一時ファイルを作成してから、APIを呼び出す（`allowed-tools` の複数行コマンド制限を回避するため）。

1. **Write ツール**で `/tmp/review-{pr_number}-{timestamp}.json`（例: `/tmp/review-123-1706745600.json`）に以下の形式でJSONを書き出す:

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

2. **API呼び出し:**

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --method POST --input /tmp/review-{pr_number}-{timestamp}.json
```

### 4. 投稿後の確認

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[].body'
```

## パラメータリファレンス

### 基本パラメータ

| パラメータ  | 説明                | 値                                          |
| ----------- | ------------------- | ------------------------------------------- |
| `commit_id` | PRのhead commit SHA | `headRefOid` の値                           |
| `path`      | ファイルパス        | リポジトリルートからの相対パス              |
| `line`      | 行番号              | diff内の行番号                              |
| `side`      | 対象ファイル        | `RIGHT`（新ファイル）/ `LEFT`（旧ファイル） |
| `body`      | コメント本文        | Markdown対応                                |
| `event`     | レビューイベント    | `COMMENT`, `APPROVE`, `REQUEST_CHANGES`     |

### 複数行コメント用パラメータ

複数行にまたがるコメントを投稿する場合は、以下のパラメータを追加する。

| パラメータ   | 説明         |
| ------------ | ------------ |
| `start_line` | 範囲の開始行 |
| `start_side` | 開始行の対象 |

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

### 自分のPRへのレビュー制限

GitHubの仕様により、PR作成者は自分のPRに対して以下の操作ができません:

- `APPROVE`: 承認
- `REQUEST_CHANGES`: 変更要求

自分のPRにレビューコメントを投稿する場合は、必ず `"event": "COMMENT"` を使用してください。

### よくあるエラーと対処法

| エラーメッセージ                                           | 原因                       | 対処法                        |
| ---------------------------------------------------------- | -------------------------- | ----------------------------- |
| `pull_request_review_thread.line must be part of the diff` | diff外の行を指定           | `gh pr diff` で行番号を再確認 |
| `Can not approve your own pull request`                    | 自分のPRを承認しようとした | `"event": "COMMENT"` を使用   |
| `Validation Failed`                                        | commit_idが古い            | 最新の `headRefOid` を再取得  |
