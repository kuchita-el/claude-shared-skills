---
description: Issueの準備状態を精査し、不足項目・確認事項・分割提案をレポートする。作業開始前のIssue品質チェック、全オープンIssueの一括棚卸し、Issue精査・レビューに使用
allowed-tools:
  - Bash(gh issue list*)
  - Bash(gh issue view*)
  - Agent
  - Read
---

# Issue精査（Refine Issue）

Issueの準備状態をDoR（Definition of Ready）に基づいて精査し、結果をレポートする。
1件の詳細精査と全件一括精査の両方に対応。精査はサブエージェントで実行し、メインコンテキストを消費しない。

## 引数

- `$ARGUMENTS`: オプション
  - Issue番号またはURL（例: `123`, `https://github.com/owner/repo/issues/123`）→ 1件モード
  - 省略 → 全件モード
  - `--input <path>`: JSONファイルからIssue情報を読み込む（`gh issue view` をスキップ）→ 1件モード
  - `--label <name>`: 特定ラベルのIssueのみ対象（全件モード）
  - `--repo <owner/repo>`: 対象リポジトリ（省略時はカレントリポジトリ）
  - `--limit <n>`: 取得するIssue数の上限（デフォルト: 100、全件モード）

引数にGitHub URLが含まれる場合、`owner/repo` と Issue番号を抽出する。

`--input` とIssue番号が同時に指定された場合は `--input` を優先する。

## 手順

### 1. 引数の解析とモード判定

- **`--input` あり** → 1件モード（固定入力）
- **Issue番号あり** → 1件モード
- **Issue番号なし** → 全件モード
- `--label`, `--repo`, `--limit` の解析

`--repo` がある場合、以降の全 `gh` コマンドに `--repo <owner/repo>` を付与する。

### 2. DoR定義の読み込み

以下の優先順位でDoR定義をReadツールで読み込む:

1. **プロジェクト固有**: `{プロジェクトルート}/.claude/dor/definition.md`
2. **デフォルト**: このスキルの `references/dor-default.md`

### 3. Issue情報の取得

**固定入力モード（`--input`）:**

ReadツールでJSONファイルを読み込む。`gh` コマンドは実行しない。

**1件モード:**

```bash
gh issue view {issue_number} --json number,title,body,labels,comments
```

**全件モード:**

```bash
gh issue list --state open --json number,title,body,labels,updatedAt,comments --limit {limit}
```

`--label` オプションがあれば `--label <name>` を追加する。

### 4. サブエージェントによる精査

`references/refine-prompt.md` をReadで読み込み、DoR定義・Issue情報と組み合わせてサブエージェントプロンプトを構築する。

**プロンプト構築:**

```
{refine-prompt.md の内容}

## DoR（Definition of Ready）定義

{DoR定義の全文}

## 精査対象Issue

{Issue情報をJSON形式で埋め込み}

実行した全てのBashコマンドとツール呼び出しを、実行順に「実行ログ」セクションとして最終出力に含めること。
```

出力形式指定（`{OUTPUT_FORMAT}` プレースホルダを置換）:

- **1件モード**: 詳細形式（後述）
- **全件モード**: 構造化形式（後述）

**サブエージェントの起動:**

- **1件モード**: Agent tool 1回（モデル: 親と同じ）
- **全件モード**: 10-15件/バッチ、最大3並列（モデル: `sonnet`）

### 5. 出力

#### 1件精査: 詳細形式

サブエージェントへの出力形式指定:

```
以下の形式で精査結果を出力してください。該当しないセクションは省略してよい。

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

### 次のアクション

1. [最初にやるべきこと]
2. [次にやるべきこと]
```

#### 全件精査: サマリー形式

サブエージェントへの出力形式指定:

```
各Issueについて以下の形式で結果を返してください:
- number: Issue番号
- title: タイトル
- size: Small / Medium / Large
- is_ready: true / false
- clarification_items: 確認事項のリスト（なければ空配列）
```

サブエージェントの結果を集約し、以下の形式で出力する:

```markdown
## Issue精査サマリー

| # | タイトル | サイズ | Ready | 確認事項 |
|---|---------|--------|-------|---------|
| 1 | 機能追加 | Medium | ❌    | 2件     |
| 3 | バグ修正 | Small  | ✅    | なし    |
| 5 | 設計変更 | -      | -     | error   |

### 統計

- 精査対象: {total}件
- 作業可能（Ready）: {ready}件
- 確認事項あり（Not Ready）: {not_ready}件

### 次のアクション

- Not ReadyのIssueは確認事項を解消後、`/refine-issue {number}` で個別に再精査
- ReadyのIssueは作業開始可能
```

**エラーハンドリング**: サブエージェントが失敗した場合、該当Issueはサマリーテーブル内に `error` ステータスで表示し、エラー詳細をテーブル直後に補足する。
