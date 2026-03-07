---
description: 作業開始前にIssueを精査し、不明点の洗い出し・分割提案を行う
allowed-tools:
  - Bash(gh issue list*)
  - Bash(gh issue view*)
  - Bash(gh issue comment*)
  - Bash(gh issue create*)
  - Bash(gh issue edit*)
  - Bash(gh label create*)
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
---

# Issue精査（Refine Issue）

作業開始前にIssueを精査し、開発者が迷いなく作業に着手できる状態かを判定する。
DoR（Definition of Ready）に基づいて不足項目を特定し、改善提案を行う。

## 引数

- `$ARGUMENTS`: Issue番号またはURL（例: `123` または `https://github.com/owner/repo/issues/123`）

## 手順

### 1. DoR定義の読み込み

以下の優先順位でDoR定義を読み込む:

1. **プロジェクト固有**: `{プロジェクトルート}/.claude/dor/definition.md`（存在すれば優先）
2. **デフォルト**: `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`

読み込んだDoR定義からサイズ別のチェック項目を把握する。

### 2. Issue情報の取得

```bash
gh issue view {issue_number} --json number,title,body,labels,milestone,assignees,comments
```

既存コメントにも目を通す。過去の議論や回答が、これから確認しようとしていた疑問を既に解消している場合がある。

### 3. サイズ判定

DoR定義の「サイズ判定ロジック」セクションに従ってIssueのサイズを判定する。

### 4. 精査

DoRチェック項目を評価した上で、以下の観点で分析する。サイズに応じて深さを調整する（Smallは軽く確認、Largeは網羅的に分析）。

**目標**: 「このIssueを渡された開発者が、追加の質問なしに作業を始められるか？」を判断すること。

主な観点:

- **仕様の明確さ**: 曖昧な表現（「〜など」「適切に」）、複数解釈可能な箇所はないか
- **決定事項の有無**: 設計上の選択肢がある場合、選択肢と推奨案を整理
- **スコープの妥当性**: 1PR（1-2日）で完了できるか、分割が必要か
- **受け入れ条件**: 何をもって完了とするか判断できるか
- **依存関係**: 先に解決すべき問題や影響を受ける既存コードはないか

### 5. コードベースの確認

Issueに関連するコードを Grep/Glob で探索し、以下を把握する:

- 変更対象となりそうなファイル・モジュール
- 既存の実装パターン・規約
- テストの有無と追加が必要な箇所

### 6. 出力

以下の形式で精査結果を提示する。該当しないセクションは省略してよい。

```markdown
## Issue精査結果: #{issue_number}

### 概要

[Issueの要約を1-2文で]

### DoRチェック結果

**サイズ**: Small / Medium / Large
**Ready判定**: Ready / Not Ready

| 項目             | 結果  | 備考   |
| ---------------- | ----- | ------ |
| 課題が明確       | ✅/❌ | [備考] |
| ...              | ...   | ...    |

### 確認事項

- [ ] [確認が必要な項目1]
- [ ] [確認が必要な項目2]

### 決定が必要な事項

| 項目     | 選択肢    | 推奨 | 理由   |
| -------- | --------- | ---- | ------ |
| [項目名] | A / B / C | A    | [理由] |

### スコープ評価

- **規模**: 適切 / 要分割
- **分割案**（該当する場合）:
  1. [サブタスク1の概要]
  2. [サブタスク2の概要]

### 関連コード

- `path/to/file.ts` - [変更内容の概要]

### 次のアクション

1. [最初にやるべきこと]
2. [次にやるべきこと]
```

## アクション選択

精査完了後、**AskUserQuestion ツール**で次のアクションを選択させ、そのまま実行する。選択肢は精査結果に応じて調整する:

- 確認事項がある場合: 「Issueコメントに投稿」を推奨（ラベル: `needs-clarification`）
- 確認事項がない場合: 「作業開始」を推奨（ラベル: `ready-for-work`）
- 分割が必要な場合: 「Issue分割（子Issue作成）」を選択肢に含める

> AskUserQuestion が利用できない場合: 精査結果と推奨アクションを出力し、ユーザーの指示を待つ。

## アクション実行

### コメント投稿

**確認事項がある場合:**

```markdown
## 精査結果

### 概要

[Issueの要約]

### 確認事項

以下の点について確認・決定が必要です:

- [ ] [確認事項1]
- [ ] [確認事項2]

### 決定が必要な事項

| 項目 | 選択肢 | 推奨 | 理由 |
| ---- | ------ | ---- | ---- |
| ...  | ...    | ...  | ...  |

---

_確認事項に回答後、`/refine-issue {issue_number}` で再精査してください_
_精査実施: Claude Code_
```

```bash
gh issue comment {issue_number} --body "..."
gh issue edit {issue_number} --add-label "needs-clarification"
gh issue edit {issue_number} --remove-label "ready-for-work"
```

**確認事項がない場合:**

```markdown
## 精査完了

作業開始可能です。

---

_精査実施: Claude Code_
```

```bash
gh issue comment {issue_number} --body "..."
gh issue edit {issue_number} --add-label "ready-for-work"
gh issue edit {issue_number} --remove-label "needs-clarification"
```

### 子Issue作成

```bash
gh issue create --title "[親Issue名] - [サブタスク名]" --body "..."
```
