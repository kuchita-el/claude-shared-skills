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

オープンな全Issueを一括で精査し、確認事項の有無に応じてラベルを付与する。
DoR（Definition of Ready）に基づいて各Issueの準備状態を評価する。

- **確認事項がある場合**: コメント投稿 + `needs-clarification` ラベル付与
- **確認事項がない場合**: 簡潔なコメント + `ready-for-work` ラベル付与
- **前回精査後に更新がない場合**: 再精査をスキップ（コメントが増えることを防ぐ）

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

`needs-clarification` と `ready-for-work` ラベルが存在しない場合は作成する。

### 3. オープンIssueの取得と再精査スキップ判定

オープンIssueを取得する（`--label`, `--limit` オプションがあれば適用）。

各Issueについて再精査が必要か判定する:

**スキップ条件**（`--force` 指定時は無視）: 以下の両方を満たす場合はスキップ

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

サイズ判定はDoR定義の「サイズ判定ロジック」セクションに従ってください。

精査観点:
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

各Issueに対してコメント投稿とラベル付与を行う。複数行のコメントは Write ツールで一時ファイルに書き出してから `gh issue comment --body-file` で投稿する。

- **確認事項あり**: コメント投稿 + `needs-clarification` 付与 + `ready-for-work` 削除
- **確認事項なし**: 簡潔なコメント投稿 + `ready-for-work` 付与 + `needs-clarification` 削除

コメントの末尾には必ず `_精査実施: Claude Code_` マーカーを含める（再精査スキップ判定に使用するため）。

#### コメントフォーマット

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

_確認事項に回答後、`/refine-issue {number}` で再精査してください_
_精査実施: Claude Code_
```

**確認事項がない場合:**

```markdown
## 精査完了

作業開始可能です。

---

_精査実施: Claude Code_
```

### 6. サマリー出力

精査完了後、以下のサマリーを出力:

```markdown
## 一括精査結果サマリー

| Issue | タイトル | サイズ | 結果 |
| ----- | -------- | ------ | ---- |
| ...   | ...      | ...    | ...  |

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

## 注意事項

- 前回精査後に更新がないIssueは自動的にスキップされる（`--force` で強制再精査可能）
- 大量のIssueがある場合は `--limit` オプションで制限
- 依存関係のあるIssue（例: #10が#9に依存）は、依存先が完了しているか確認
