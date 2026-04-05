---
description: IssueからPlanサブエージェントで実装プランを作成し、独立レビュアーエージェントによるレビューと要確認事項の質問までを自動化する。Issue実装プランの作成、技術設計とタスク分解の計画立案に使用。「実装計画を立てて」「プランニングして」「タスク分解して」「設計を整理して」「Issueの計画を作って」といった依頼時にも使用
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash(gh issue view*)
  - Bash(gh repo view*)
  - Agent
  - AskUserQuestion
---

# プラン作成（Plan Issue）

Issueの実装プランを作成し、`docs/plans/issue-{番号}.md` に保存する。
Planサブエージェントでプラン作成 → 独立レビュアーエージェントによるレビュー → 修正のループを最大2周実行し、要確認事項をユーザーに質問する。

## 引数

- `$ARGUMENTS`: Issue番号またはURL。補足指示（オプション）
  - 例: `21`, `https://github.com/owner/repo/issues/21`, `21 テストは不要`
  - `--input <path>`: JSONファイルからIssue情報を読み込む（`gh issue view` をスキップ）

GitHub URLが含まれる場合、Issue番号を抽出する。番号以降のテキストは補足指示として扱う。

`--input` とIssue番号が同時に指定された場合は `--input` を優先する。

## 手順

### 1. 引数の解析

`$ARGUMENTS` から以下を分離する:

- **`--input` あり** → 固定入力モード（JSONファイルパスを取得）
- **Issue番号あり** → 通常モード
- 上記以外のテキスト → 補足指示

### 2. レビュー基準の読み込み

以下の順序でReadツールで読み込み、両方の内容をマージしてレビュー基準とする:

1. **デフォルト（必須）**: `${CLAUDE_SKILL_DIR}/references/review-guide-default.md`
2. **プロジェクト固有（任意）**: `{プロジェクトルート}/.claude/plan-issue/review-guide.md`

デフォルトは常に読み込む。プロジェクト固有ファイルが存在する場合（Readが成功した場合）、その内容を追加のレビュー観点として加える。

### 3. Issue情報の取得

**固定入力モード（`--input`）:**

ReadツールでJSONファイルを読み込む。`gh` コマンドは実行しない。

**通常モード:**

```bash
gh issue view {issue_number} --json number,title,body,labels,comments
```

### 4. ベースブランチの決定

以下の優先順位でベースブランチを決定する:

1. **コンテキストからの読み取り**: CLAUDE.md（ユーザースコープ・プロジェクトルート）、プロジェクトのブランチ運用ルール、ユーザーの補足指示にブランチ運用の記載があれば、そこからベースブランチを特定する
2. **デフォルトブランチへのフォールバック**: コンテキストから判断できない場合、以下のコマンドでリポジトリのデフォルトブランチを取得する

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

コマンドが失敗した場合は `main` を仮設定し、プランに「デフォルトブランチの取得に失敗したため `main` を仮設定。実装時に確認すること」と注記する。

### 5. Planサブエージェントによるプラン作成

`${CLAUDE_SKILL_DIR}/references/plan-prompt.md` をReadで読み込み、プロンプトを構築する。

**プロンプト構築:**

```
{plan-prompt.md の内容}
```

`{OUTPUT_FORMAT}` プレースホルダを本スキルの「出力フォーマット」セクションのMarkdownテンプレートで置換する。

その後、以下を追加する:

```
## Issue情報

{gh issue viewの結果}

## 補足指示

{補足指示（あれば）}

## ベースブランチ

{決定したベースブランチ名}

実行した全てのBashコマンドとツール呼び出しを、実行順に「実行ログ」セクションとして最終出力に含めること。
```

**サブエージェントの起動:**

Agent tool（`subagent_type: Plan`）でプラン作成を実行する。モデルは親と同じ（`inherit`）。

### 6. プランファイルの保存

サブエージェントの結果から「実行ログ」セクションを除去し、`docs/plans/issue-{番号}.md` にWriteで保存する。

### 7. レビュアーエージェントによるレビュー → 修正ループ（最大2周）

プラン作成のコンテキストを持たない独立したレビュアーエージェントでプランを評価する。

**7a. レビュアープロンプトの構築:**

1. `${CLAUDE_SKILL_DIR}/agents/plan-reviewer.md` をReadで読み込む
2. プレースホルダを置換する:
   - `{PLAN_FILE_PATH}` → `docs/plans/issue-{番号}.md`
   - `{REVIEW_CRITERIA}` → ステップ2で読み込んだレビュー基準の全文（デフォルト＋プロジェクト固有）

**7b. レビュアーエージェントの起動:**

Agent tool（`subagent_type` 指定なし=汎用エージェント）で起動する。モデルは親と同じ（`inherit`）。

**7c. レビュー結果の処理:**

- レビュー結果が `PASS` → ステップ8へ
- レビュー結果が `FAIL` → 指摘事項に基づいてEditでプランファイルを修正し、7bに戻る（最大2周）

**ループ終了条件:**

- `PASS` → ステップ8へ
- 2周で収束しない → 残った指摘事項を根本的な問題としてステップ8で質問する

### 8. 要確認事項の質問

以下の場合、`AskUserQuestion` でユーザーに質問する:

- レビュアーエージェントの指摘で解決できない問題がある場合
- Issueの要件が曖昧でプランの品質を担保できない場合
- 設計上の選択肢があり、判断が必要な場合

質問がない場合は、プランファイルのパスを報告して完了する。

## 出力フォーマット

`docs/plans/issue-{番号}.md` に `${CLAUDE_SKILL_DIR}/references/plan-output-format.md` の形式で出力する。
