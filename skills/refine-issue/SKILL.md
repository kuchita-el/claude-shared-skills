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
2. **デフォルト**: `${CLAUDE_SKILL_DIR}/references/dor-default.md`

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

`${CLAUDE_SKILL_DIR}/references/refine-prompt.md` をReadで読み込み、DoR定義・Issue情報と組み合わせてサブエージェントプロンプトを構築する。

`refine-prompt.md` の `{OUTPUT_FORMAT}` プレースホルダは、モードに応じて以下のファイル内容で置換する。

- **1件モード**: `${CLAUDE_SKILL_DIR}/references/output-format-single.md`
- **全件モード**: `${CLAUDE_SKILL_DIR}/references/output-format-batch.md`

**プロンプト構築:**

```
{refine-prompt.md の内容（{OUTPUT_FORMAT} を上記ファイル内容で置換済み）}

## DoR（Definition of Ready）定義

{DoR定義の全文}

## 精査対象Issue

{Issue情報をJSON形式で埋め込み}

実行した全てのBashコマンドとツール呼び出しを、実行順に「実行ログ」セクションとして最終出力に含めること。
```

**サブエージェントの起動:**

- **1件モード**: Agent tool 1回（モデル: 親と同じ）
- **全件モード**: 10-15件/バッチ、最大3並列（モデル: `sonnet`）

### 5. 出力

サブエージェントの結果を以下の通り取り扱う。

- **1件モード**: サブエージェントの出力をそのまま表示する。出力形式は `${CLAUDE_SKILL_DIR}/references/output-format-single.md` を参照。
- **全件モード**: サブエージェントの出力を集約し、`${CLAUDE_SKILL_DIR}/references/output-format-batch.md` に定義された最終形式で出力する。エラーハンドリング（サブエージェント失敗時の `error` ステータス表示）も同ファイルを参照。
