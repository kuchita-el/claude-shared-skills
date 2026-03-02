---
description: 議論内容からGitHub Issueを作成（コード編集制限付き）
allowed-tools:
  - Bash(gh issue create*)
  - Bash(gh issue list*)
  - Write
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# Issue作成スキル

議論内容からGitHub Issueを作成します。コード編集は行いません。

## 目的

- プランモードでの議論結果をIssue化する
- コード編集を伴わないIssue作成タスクを安全に実行する

## 手順

### 1. Issue内容の確認

ユーザーとの会話から以下の情報を整理する:

1. **タイトル**: Issueの簡潔なタイトル
2. **背景**: なぜこのIssueが必要か
3. **ゴール**: 何を達成したいか
4. **詳細**: 具体的な要件や実装方針（あれば）

不明点があれば質問して明確化する。

### 2. Issue本文の作成

**Write ツール**で一時ファイルにIssue本文を書き出す:

```bash
# 例: /tmp/issue-1738540800.md
/tmp/issue-{タイムスタンプ}.md
```

必要に応じて、**Read/Glob/Grep ツール**でコードベースを参照し、Issue詳細を補完できる:

- 関連するファイルやコードの確認
- 既存の実装パターンの参照
- 影響範囲の調査

### 3. プレビュー・確認

作成するIssueの内容をプレビュー表示し、**AskUserQuestion ツール**で確認を取る:

まずプレビューを出力する:

```markdown
---プレビュー---

**タイトル**: {タイトル}

**本文**:
{Issue本文}

---

プレビュー終わり---
```

続けてAskUserQuestionを呼び出す:

```
AskUserQuestion:
  question: "この内容でIssueを作成しますか？"
  header: "確認"
  options:
    - label: "作成する"
      description: "この内容でGitHub Issueを作成"
    - label: "修正する"
      description: "内容を修正してから再度確認"
```

> **AskUserQuestion が利用できない場合**: プレビューを出力し、ユーザーの明示的な指示を待ってください。

- **「作成する」が選択された場合**: Step 4に進む
- **「修正する」が選択された場合**: ユーザーの指示に従い修正後、再度Step 3を実行する

### 4. Issue作成

確認が取れたら、GitHub CLIでIssueを作成する:

```bash
gh issue create --title "{タイトル}" --body-file /tmp/issue-{タイムスタンプ}.md
```

## 出力フォーマット

Issue作成後、以下を出力:

```
Issueを作成しました: {IssueのURL}

タイトル: {タイトル}
```

## 注意事項

- **コード編集は行わない**: このスキルはIssue作成のみに特化（Edit、Serenaのコード解析ツールは使用不可）
- **ラベル自動付与はしない**: 必要に応じて手動で追加
- **テンプレートは使用しない**: 自由形式で作成（テンプレート対応は別Issue）
- 一時ファイル（`/tmp/issue-*.md`）はOS管理のため明示的な削除は不要
