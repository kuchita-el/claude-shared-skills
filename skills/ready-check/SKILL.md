---
description: DoR（Definition of Ready）に基づくIssue Ready判定
allowed-tools:
  - Bash(gh issue list*)
  - Bash(gh issue view*)
  - Bash(gh issue comment*)
  - Bash(gh issue edit*)
  - Bash(gh label create*)
  - Read
  - Grep
  - Glob
  - Write
  - AskUserQuestion
---

# Issue Ready判定（Ready Check）

DoR（Definition of Ready）に基づいて、Issueが作業開始可能かどうかを判定します。

## 引数

- `$ARGUMENTS`: Issue番号またはURL（例: `123` または `https://github.com/owner/repo/issues/123`）

## 手順

### 1. DoR定義の読み込み

以下の優先順位でDoR定義を読み込む:

1. **プロジェクト固有**: `{プロジェクトルート}/.claude/dor/definition.md`（存在すれば優先）
2. **デフォルト**: `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`

読み込んだDoR定義からチェック項目を把握する。

### 2. Issue情報の取得

```bash
gh issue view {issue_number} --json number,title,body,labels,milestone,assignees,comments
```

### 3. サイズ判定

以下の優先順位でサイズを判定する:

#### 3.1 ラベル優先

- `size:small` ラベルあり → **Small**
- `size:medium` ラベルあり → **Medium**
- `size:large` ラベルあり → **Large**

#### 3.2 本文解析（ラベルがない場合）

| サイズ | 判定条件                                                                                 |
| ------ | ---------------------------------------------------------------------------------------- |
| Small  | 「バグ」「bug」「typo」「軽微」を含む、または本文500文字未満かつAC2項目以下              |
| Large  | 「アーキテクチャ」「設計変更」「大規模」を含む、または子Issue参照（`#` + 数字）が3つ以上 |
| Medium | 上記以外                                                                                 |

### 4. DoRチェック実行

判定したサイズに応じて、DoR定義のチェック項目を検証する。

#### Small のチェック項目

| 項目             | 検証方法                                           |
| ---------------- | -------------------------------------------------- |
| 課題が明確       | タイトルまたは本文から何を解決するかが読み取れるか |
| 完了条件がわかる | 本文に完了条件または期待動作が記載されているか     |

#### Medium のチェック項目（Small + 以下）

| 項目                               | 検証方法                                                                     |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| 背景・目的が明確                   | 「背景」「目的」「なぜ」「経緯」などの説明があるか                           |
| 要件が具体的                       | 実装内容が具体的に記載されているか（「〜など」「〜等」の曖昧表現が少ないか） |
| 受け入れ条件（AC）が定義されている | チェックリストまたは「受け入れ条件」「AC」「完了条件」セクションがあるか     |
| 見積もり可能                       | スコープが明確で、1PR程度で完了できそうか                                    |
| 不明点がクリアになっている         | 「?」や「要確認」「TBD」などの未決定事項がないか                             |

#### Large のチェック項目（Medium + 以下）

| 項目                         | 検証方法                                                     |
| ---------------------------- | ------------------------------------------------------------ |
| トレードオフが検討されている | 複数の選択肢や「なぜこのアプローチを選んだか」の記載があるか |
| 技術的依存関係が明確         | 影響範囲や依存するモジュールが記載されているか               |
| UI/UX の決定がされている     | 該当する場合、画面設計やフローの記載があるか                 |
| 分割案（子Issue）がある      | 子Issueへの参照（`#番号`）があるか                           |

### 5. Ready / Not Ready 判定

- **Ready**: 該当サイズの全チェック項目を満たしている
- **Not Ready**: 1つ以上のチェック項目を満たしていない

### 6. 出力フォーマット

以下の形式で判定結果を出力する:

```markdown
## Ready判定結果: #{issue_number}

### 判定: **Ready** / **Not Ready**

### サイズ: Small / Medium / Large

### チェック結果

| 項目             | 結果 | 備考                       |
| ---------------- | ---- | -------------------------- |
| 課題が明確       | ✅   | タイトルから明確           |
| 完了条件がわかる | ❌   | 具体的な完了条件の記載なし |
| ...              | ...  | ...                        |

### 不足項目（Not Readyの場合）

- ❌ **完了条件がわかる**: 具体的な完了条件が記載されていません。「何をもって完了とするか」を追記してください。
- ❌ **受け入れ条件（AC）が定義されている**: テスト可能な形式の受け入れ条件を追加してください。

### 次のアクション

- **Readyの場合**: このIssueは作業開始可能です。
- **Not Readyの場合**: `/refine-issue {issue_number}` で詳細な精査を行い、不足項目を補完してください。
```

## アクション選択

判定完了後、**AskUserQuestion ツール**を使用して次のアクションを選択させ、選択されたアクションをそのまま実行する。

### AskUserQuestionの使用

判定結果の出力後、以下のようにAskUserQuestionを呼び出す:

#### Readyの場合

```
AskUserQuestion:
  question: "どのアクションを実行しますか？"
  header: "アクション"
  options:
    - label: "Issueコメントに投稿（推奨）"
      description: "判定結果をIssueのコメントとして投稿し、ready-for-workラベルを付与"
    - label: "作業開始"
      description: "コメント・ラベル付与なしでそのまま作業を開始"
```

#### Not Readyの場合

```
AskUserQuestion:
  question: "どのアクションを実行しますか？"
  header: "アクション"
  options:
    - label: "Issueコメントに投稿（推奨）"
      description: "判定結果をIssueのコメントとして投稿し、needs-clarificationラベルを付与"
    - label: "/refine-issue で詳細精査"
      description: "詳細な精査と改善提案を実行"
```

> **AskUserQuestion が利用できない場合**: 判定結果と推奨アクションを出力し、ユーザーの明示的な指示を待ってください。

### アクション実行

ユーザーが選択したアクションに応じて、以下の手順を実行する:

### コメント投稿・ラベル付与の手順

**注意**: 複数行のコメントを投稿する場合は、Write ツールで一時ファイルを作成してから `--body-file` オプションを使用する。

#### Ready の場合

1. **Write ツール**で `/tmp/ready-check-{issue_number}-{timestamp}.md` にコメント内容を書き出す:

```markdown
## DoR Ready判定: ✅ Ready

**サイズ**: {size}

全てのチェック項目を満たしています。作業開始可能です。

---

_判定実施: Claude Code (`/ready-check`)_
```

2. 以下のコマンドを実行:

```bash
# コメント投稿
gh issue comment {issue_number} --body-file /tmp/ready-check-{issue_number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {issue_number} --add-label "ready-for-work"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {issue_number} --remove-label "needs-clarification"
```

#### Not Ready の場合

1. **Write ツール**で `/tmp/ready-check-{issue_number}-{timestamp}.md` にコメント内容を書き出す:

```markdown
## DoR Ready判定: ❌ Not Ready

**サイズ**: {size}

### 不足項目

- ❌ **{項目名}**: {理由と推奨アクション}
- ❌ **{項目名}**: {理由と推奨アクション}

### 次のアクション

不足項目を補完後、再度 `/ready-check {issue_number}` を実行してください。
詳細な精査が必要な場合は `/refine-issue {issue_number}` を使用してください。

---

_判定実施: Claude Code (`/ready-check`)_
```

2. 以下のコマンドを実行:

```bash
# コメント投稿
gh issue comment {issue_number} --body-file /tmp/ready-check-{issue_number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {issue_number} --add-label "needs-clarification"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {issue_number} --remove-label "ready-for-work"
```

## 注意事項

- Large Issueは子Issue（Medium/Small）に分割されていることが前提
- 自動判定が難しい場合は、判断の根拠を明示して人間に確認を求める
- `/refine-issue` との違い: `/ready-check` は簡易判定、`/refine-issue` は詳細な精査と改善提案

### DoR定義

DoR（Definition of Ready）の定義は以下の優先順位で読み込まれます:

1. `{プロジェクトルート}/.claude/dor/definition.md`（プロジェクト固有）
2. `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`（デフォルト）

チェック項目をプロジェクトに合わせてカスタマイズする場合は、`.claude/dor/definition.md` を作成してください。
