---
description: Issueの準備状態を精査し、不足項目・確認事項・分割提案をレポートする。作業開始前のIssue品質チェック、全オープンIssueの一括棚卸し、Issue精査・レビューに使用
allowed-tools:
  - Bash(gh issue view*)
  - Bash(bash *skills/refine-issue/scripts/prepare-issues.sh*)
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

`--repo` がある場合、以降の `gh` コマンド・スクリプトに `--repo <owner/repo>` を付与する。

### 2. Issue情報の取得

**固定入力モード（`--input`）:**

ReadツールでJSONファイルを読み込む。`gh` コマンドは実行しない。

**1件モード:**

```bash
gh issue view {issue_number} --json number,title,body,labels,comments
```

取得した JSON をメモリ上で保持し、手順3でサブエージェントへプロンプト埋め込みする（DoR定義もメインで読み込んで埋め込む）。

**全件モード:**

データ準備をスクリプトに委譲する。Bash で `gh` や `jq` を動的に組み立てない（許可プロンプトのパース問題を引き起こすため）。

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/prepare-issues.sh [--repo <owner/repo>] [--label <name>] [--limit <n>]
```

スクリプトの出力:

- stdout 1行目: 出力ディレクトリの絶対パス
- stdout 2行目以降: Issue 番号（1行1番号、降順）
- stderr: 進捗情報（読み取り不要）

出力ディレクトリには `issue-{number}.json` が Issue 件数分配置される。各ファイルには `number,title,body,labels,updatedAt,comments` が含まれる。

### 3. サブエージェントによる精査

**1件モード・`--input` モード:**

メインで以下の情報を組み立て、Agent tool を1回起動する。

- `${CLAUDE_SKILL_DIR}/references/refine-prompt.md` の内容
- `${CLAUDE_SKILL_DIR}/references/output-format-single.md` の内容（`{OUTPUT_FORMAT}` プレースホルダに当てはめる）
- DoR 定義（プロジェクト固有 `{project}/.claude/dor/definition.md` があれば優先、なければ `${CLAUDE_SKILL_DIR}/references/dor-default.md`）
- 精査対象 Issue の JSON

モデルは親と同じ。

**全件モード:**

サブエージェントが自分で必要ファイルを Read する形に統一する（メインでのプロンプトベース再生成は行わない）。

1. メイン側で手順2の stdout を行単位で解釈し、1行目を出力ディレクトリ、2行目以降を Issue 番号リストとして取り出す
2. Issue 番号リストを **15件ずつのバッチに分割** する（モデルが直接計算。例: 31件 → 15/15/1 の3バッチ）
3. バッチごとに Agent tool を直接呼び出す（**最大3並列、モデル: `sonnet`**）
   - **Bash の for / while で Agent 呼び出しを生成しないこと**（許可プロンプトのパース問題を引き起こすため）
   - **複数の Agent 呼び出しは Agent tool を直接複数回呼び出す形で記述すること**（1メッセージ内で複数 Agent ブロックを並列、バッチ数が3を超える場合は複数メッセージに分けて段階実行）

各サブエージェントには以下のコンテキストを文字列で渡す（ファイル本文の埋め込みは行わない）:

- スキルディレクトリパス（`${CLAUDE_SKILL_DIR}` を展開した実パス）
- プロジェクトルートパス（現在の作業ディレクトリ）
- Issue ファイルのディレクトリパス（手順2のstdout 1行目）
- 担当 Issue 番号のリスト

サブエージェントは以下を自分で Read する:

1. `{skill_dir}/references/refine-prompt.md`（精査手順本体）
2. プロジェクト固有DoR: `{project_root}/.claude/dor/definition.md`（存在すれば優先）
3. デフォルトDoR: `{skill_dir}/references/dor-default.md`
4. 出力形式テンプレート: `{skill_dir}/references/output-format-batch-subagent.md`（`{OUTPUT_FORMAT}` の置換イメージとして適用）
5. 担当 Issue 番号それぞれの `{issue_dir}/issue-{number}.json`

サブエージェントは精査結果を構造化データ（YAML/JSON 等）で返却する。

### 4. 出力

サブエージェントの結果を以下の通り取り扱う。

- **1件モード**: サブエージェントの出力をそのまま表示する。出力形式は `${CLAUDE_SKILL_DIR}/references/output-format-single.md` を参照。
- **全件モード**: 各サブエージェントの構造化データを集約し、`${CLAUDE_SKILL_DIR}/references/output-format-batch.md` に定義された最終形式で出力する。エラーハンドリング（サブエージェント失敗時の `error` ステータス表示）も同ファイルを参照。
