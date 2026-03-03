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

作業開始前にIssueを精査し、品質の高い作業を行うための準備をします。
DoR（Definition of Ready）に基づいて不足項目を特定し、改善提案を行います。

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

### 3. サイズ判定

DoR定義に基づいてIssueのサイズを判定する:

#### ラベル優先

- `size:small` → Small
- `size:medium` → Medium
- `size:large` → Large

#### 本文解析（ラベルがない場合）

- **Small**: 「バグ」「bug」「typo」「軽微」を含む、または本文500文字未満かつAC2項目以下
- **Large**: 「アーキテクチャ」「設計変更」「大規模」を含む、または子Issue参照が3つ以上
- **Medium**: 上記以外

### 4. 精査観点

DoRチェック項目に加えて、以下の観点でIssueを分析する:

#### 4.1 不明確な点の洗い出し

- 仕様が曖昧な箇所はないか
- 複数の解釈ができる表現はないか
- 技術的な判断が必要な箇所はないか
- 「〜など」「〜等」のような曖昧な表現がないか

#### 4.2 決めるべきことのリスト化

- 設計上の選択肢がある場合、選択肢と推奨案を提示
- 確認が必要な前提条件を列挙
- UI/UXに関する決定事項があれば明確化

#### 4.3 スコープの妥当性

- 1PR（1-2日程度）で完了できる規模か
- 複数の独立した変更が混在していないか
- 分割が必要な場合は分割案を提示

#### 4.4 受け入れ条件の確認

- 完了条件が明確に定義されているか
- テスト観点が明確か
- 「何をもって完了とするか」が判断できるか

#### 4.5 依存関係の確認

- 先に解決すべき問題（他のIssue、技術的負債）はないか
- 影響を受ける既存コードの特定
- 関連するIssueやPRへの参照

#### 4.6 ドメイン定義との整合性

- Issueが既存ドメインに関連する場合、プロジェクトにドメイン定義ドキュメントがあれば参照する
- Issue内の用語が正式名称と一致しているか確認
- Issueのスコープがドメイン定義と矛盾していないか確認
- 矛盾がある場合は確認事項として報告する

### 5. コードベースの確認

Issueに関連するコードを確認し、以下を把握する:

- 変更対象となりそうなファイル・モジュール
- 既存の実装パターン・規約
- テストの有無と追加が必要な箇所

### 6. 出力フォーマット

以下の形式で精査結果を提示する:

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
| 完了条件がわかる | ✅/❌ | [備考] |
| ...              | ...   | ...    |

### 不明点・確認事項

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

### 受け入れ条件

- [ ] [条件1]
- [ ] [条件2]

### 関連コード

- `path/to/file.ts` - [変更内容の概要]

### 次のアクション

1. [最初にやるべきこと]
2. [次にやるべきこと]
```

## アクション選択

精査完了後、**AskUserQuestion ツール**を使用して次のアクションを選択させ、選択されたアクションをそのまま実行する。

### AskUserQuestionの使用

精査結果の出力後、以下のようにAskUserQuestionを呼び出す:

```
AskUserQuestion:
  question: "どのアクションを実行しますか？"
  header: "アクション"
  options:
    - label: "Issueコメントに投稿"
      description: "精査結果をIssueのコメントとして投稿し、ラベルを付与"
    - label: "Issue分割（子Issue作成）"
      description: "分割案に基づいて子Issueを作成"
    - label: "作業開始"
      description: "問題なければそのまま作業を開始"
```

> **AskUserQuestion が利用できない場合**: 精査結果と推奨アクションを出力し、ユーザーの明示的な指示を待ってください。

**注意**: 選択肢は精査結果に応じて調整する:

- 確認事項がある場合: 「Issueコメントに投稿」を推奨（ラベルは `needs-clarification`）
- 確認事項がない場合: 「作業開始」を推奨（ラベルは `ready-for-work`）
- 分割が必要な場合: 「Issue分割」を選択肢に含める

### アクション実行

ユーザーが選択したアクションに応じて、以下の手順を実行する:

### コメント投稿の手順

**注意**: 複数行のコメントを投稿する場合は、Write ツールで一時ファイルを作成してから `--body-file` オプションを使用する（`allowed-tools` の複数行コマンド制限を回避するため）。

#### 確認事項がある場合

1. **Write ツール**で `/tmp/issue-comment-{issue_number}-{timestamp}.md`（例: `/tmp/issue-comment-123-1706745600.md`）に以下の形式でコメント内容を書き出す:

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

2. 以下のコマンドを実行:

```bash
# コメント投稿（一時ファイル経由）
gh issue comment {issue_number} --body-file /tmp/issue-comment-{issue_number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {issue_number} --add-label "needs-clarification"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {issue_number} --remove-label "ready-for-work"
```

#### 確認事項がない場合

1. **Write ツール**で `/tmp/issue-comment-{issue_number}-{timestamp}.md`（例: `/tmp/issue-comment-123-1706745600.md`）に以下の内容を書き出す:

```markdown
## 精査完了

作業開始可能です。

---

_精査実施: Claude Code_
```

2. 以下のコマンドを実行:

```bash
# コメント投稿（一時ファイル経由）
gh issue comment {issue_number} --body-file /tmp/issue-comment-{issue_number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {issue_number} --add-label "ready-for-work"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {issue_number} --remove-label "needs-clarification"
```

### 子Issue作成の手順

同様に、Write ツールで一時ファイルを作成してから `--body-file` オプションを使用する:

1. **Write ツール**で `/tmp/issue-body-{issue_number}-{timestamp}.md`（例: `/tmp/issue-body-123-1706745600.md`）にIssue本文を書き出す
2. 以下のコマンドを実行:

```bash
# 子Issue作成（一時ファイル経由）
gh issue create --title "[親Issue名] - [サブタスク名]" --body-file /tmp/issue-body-{issue_number}-{timestamp}.md
```

## 関連スキル

### DoR定義

DoR（Definition of Ready）の定義は以下の優先順位で読み込まれます:

1. `{プロジェクトルート}/.claude/dor/definition.md`（プロジェクト固有）
2. `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`（デフォルト）

チェック項目をプロジェクトに合わせてカスタマイズする場合は、`.claude/dor/definition.md` を作成してください。
