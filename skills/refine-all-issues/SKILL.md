---
description: 全オープンIssueを一括精査し、確認事項をコメント投稿・ラベル付与する
allowed-tools:
  - Bash(gh issue list*)
  - Bash(gh issue view*)
  - Bash(gh issue comment*)
  - Bash(gh issue edit*)
  - Bash(gh issue create*)
  - Bash(gh label create*)
  - Agent
  - Read
  - Grep
  - Glob
  - Write
---

# 全Issue一括精査（Refine All Issues）

オープンな全Issueを一括で精査し、確認事項の有無に応じてラベルを付与します。
DoR（Definition of Ready）に基づいて各Issueの準備状態を評価します。

- **確認事項がある場合**: コメント投稿 + `needs-clarification` ラベル付与
- **確認事項がない場合**: 簡潔なコメント + `ready-for-work` ラベル付与
- **前回精査後に更新がない場合**: 再精査をスキップ（いたずらにコメントが増えることを防ぐ）

## 引数

- `$ARGUMENTS`: オプション
  - `--label <name>`: 特定ラベルのIssueのみ対象（例: `--label bug`）
  - `--limit <n>`: 取得するIssue数を制限（デフォルト: 100）
  - `--force`: スキップ判定を無視して全Issueを再精査

## 手順

### 1. DoR定義の読み込み

以下の優先順位でDoR定義を読み込む:

1. **プロジェクト固有**: `{プロジェクトルート}/.claude/dor/definition.md`（存在すれば優先）
2. **デフォルト**: `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`

読み込んだDoR定義からサイズ別のチェック項目を把握する。

### 2. ラベルの準備

必要なラベルが存在しない場合は作成する:

```bash
# ラベル作成（既に存在する場合はエラーになるが、無視して続行する）
gh label create "needs-clarification" --description "精査の結果、確認事項あり" --color "d93f0b"
gh label create "ready-for-work" --description "精査完了、作業開始可能" --color "0e8a16"
```

### 3. オープンIssueの取得

```bash
# 基本: 全オープンIssue取得（updatedAtを含める）
gh issue list --state open --json number,title,labels,updatedAt --limit 100

# オプション: 特定ラベルのみ
gh issue list --state open --label "bug" --json number,title,labels,updatedAt --limit 100

# 既に精査済み（ready-for-work または needs-clarification ラベル付き）は除外することを推奨
```

### 3.1 再精査スキップ判定

各Issueについて、前回の精査コメント以降に更新があるかを確認する:

```bash
# Issueのコメントを取得し、精査コメント（「精査実施: Claude Code」を含む）の最新日時を確認
gh issue view {number} --json comments,updatedAt
```

**スキップ条件**: 以下の両方を満たす場合は再精査をスキップ

1. 精査コメント（「精査実施: Claude Code」を含む）が存在する
2. 精査コメントの投稿日時 >= IssueのupdatedAt（精査後に更新がない）

スキップしたIssueはサマリーに「skipped」として記録する。

### 4. 各Issueの精査（並列実行推奨）

Agent toolを使用して、各Issueを並列で精査する。各エージェントに以下を指示:

```
Issue #{number} を精査してください。

まず DoR（Definition of Ready）定義を読み込み、チェック項目を確認してください。
DoR定義の読み込み優先順位:
1. {プロジェクトルート}/.claude/dor/definition.md（存在すれば優先）
2. {プロジェクトルート}/.claude/skills/defaults/dor/definition.md

サイズ判定:
- ラベル優先: size:small / size:medium / size:large
- ラベルがない場合は本文から推定（詳細は DoR 定義を参照）

精査観点（詳細は /refine-issue スキルを参照）:
1. DoRチェック（サイズに応じたチェック項目を評価）
2. 不明確な点の洗い出し（曖昧な仕様、複数解釈可能な表現）
3. 決めるべきことのリスト化（設計選択肢、前提条件、UI/UX）
4. スコープの妥当性（1PRで完了可能か、分割が必要か）
5. 受け入れ条件の確認（完了条件・テスト観点が明確か）
6. 依存関係の確認（他Issue、技術的負債、関連コード）

Issueへのコメント投稿やラベル変更は行わないでください。精査結果の返却のみ行ってください。

精査後、以下の形式で結果を返してください:
- size: string（Small / Medium / Large）
- is_ready: boolean（DoRチェックをパスしたかどうか）
- has_clarification_needed: boolean（確認事項があるかどうか）
- comment_body: string | null（確認事項がある場合のみ、Issueコメントとして投稿する内容）
```

### 5. 結果の投稿とラベル付与

各Issueに対して、以下の手順でコメント投稿とラベル付与を行う。

**注意**: 複数行のコメントを投稿する場合は、Write ツールで一時ファイルを作成してから `--body-file` オプションを使用する（`allowed-tools` の複数行コマンド制限を回避するため）。

#### 確認事項がある場合

1. **Write ツール**で `/tmp/issue-comment-{number}-{timestamp}.md`（例: `/tmp/issue-comment-123-1706745600.md`）にコメント内容を書き出す
2. 以下のコマンドを実行:

```bash
# コメント投稿（一時ファイル経由）
gh issue comment {number} --body-file /tmp/issue-comment-{number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {number} --add-label "needs-clarification"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {number} --remove-label "ready-for-work"
```

#### 確認事項がない場合

確認事項がない場合は**簡潔なコメント**を投稿し、ラベルを付与する:

1. **Write ツール**で `/tmp/issue-comment-{number}-{timestamp}.md`（例: `/tmp/issue-comment-123-1706745600.md`）に以下の内容を書き出す:

```markdown
## 精査完了

作業開始可能です。

---

_精査実施: Claude Code_
```

2. 以下のコマンドを実行:

```bash
# コメント投稿（一時ファイル経由）
gh issue comment {number} --body-file /tmp/issue-comment-{number}-{timestamp}.md
```

```bash
# ラベル付与
gh issue edit {number} --add-label "ready-for-work"
```

```bash
# 古いラベル削除（存在する場合）
gh issue edit {number} --remove-label "needs-clarification"
```

### 6. サマリー出力

精査完了後、以下のサマリーを出力:

```markdown
## 一括精査結果サマリー

| Issue | タイトル                                | サイズ | 結果                |
| ----- | --------------------------------------- | ------ | ------------------- |
| #10   | StaffAccountからEmployeeAccountへの移行 | Medium | ready-for-work      |
| #15   | ログイン画面のUI改善                    | Small  | needs-clarification |
| #20   | ドキュメント更新                        | Small  | skipped             |
| ...   | ...                                     | ...    | ...                 |

### 統計

- 精査対象: {total}件
- 作業可能（ready-for-work）: {ready}件
- 確認事項あり（needs-clarification）: {clarification}件
- スキップ（前回精査後に更新なし）: {skipped}件

### 次のアクション

- `needs-clarification` のIssueは確認事項に回答後、`/refine-issue {number}` で再精査
- `ready-for-work` のIssueは作業開始可能
- `skipped` のIssueは前回の精査結果が有効（Issue更新後に再精査される）
```

## コメントフォーマット（確認事項がある場合）

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

_確認事項に回答後、`/refine-issue {number}` で再精査してください_
_精査実施: Claude Code_
```

## 再精査のトリガー

確認事項が解決されたIssueを再精査する場合:

```bash
# 単一Issueの再精査
/refine-issue {number}

# needs-clarificationラベル付きを一括再精査（将来的な拡張）
/refine-all-issues --label needs-clarification
```

## 注意事項

- 前回精査後に更新がないIssueは自動的にスキップされる（`--force` で強制再精査可能）
- 大量のIssueがある場合は `--limit` オプションで制限
- 依存関係のあるIssue（例: #10が#9に依存）は、依存先が完了しているか確認

## 関連スキル

| スキル               | 目的                          |
| -------------------- | ----------------------------- |
| `/ready-check`       | 単一IssueのDoR簡易判定        |
| `/refine-issue`      | 単一Issueの詳細精査と改善提案 |
| `/refine-all-issues` | 全Issueの一括精査（本スキル） |

### DoR定義

DoR（Definition of Ready）の定義は以下の優先順位で読み込まれます:

1. `{プロジェクトルート}/.claude/dor/definition.md`（プロジェクト固有）
2. `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`（デフォルト）

チェック項目をプロジェクトに合わせてカスタマイズする場合は、`.claude/dor/definition.md` を作成してください。
