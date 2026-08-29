---
name: refine-issue
description: 既存IssueのDoRを精査する。着手前精査時に使用し、不足項目とReady境界を報告する。
allowed-tools:
  - Bash(gh issue view*)
  - Bash(bash *skills/refine-issue/scripts/prepare-issues.sh*)
  - Agent
---

# Issue精査（Refine Issue）

## 実行ルール

- **対象範囲**: 指定されたIssueと適用するDoR定義の全項目だけを精査する。
- **成果物**: 各DoR項目を列挙した精査結果、欠落、Ready境界を返す。
- **停止条件**: 一項目でも未充足ならNot Readyとし、未決を合格へ変換しない。
- **変更境界**: Issue本文や実装を勝手に変更せず、精査結果の範囲に限定する。

Issueの準備状態をDoR（Definition of Ready）に基づいて精査し、結果をレポートする。
1件の詳細精査と全件一括精査の両方に対応。精査はサブエージェントで実行し、メインコンテキストを消費しない。

**出力と範囲**: Issueの対象・精査結果・停止条件・変更境界は上記の実行ルールで判定する。
精査の粒度判定は `${CLAUDE_SKILL_DIR}/references/refine-prompt.md` の「スコープの妥当性の粒度基準」節を直接参照する。

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

`gh` コマンドは実行しない。入力 JSON ファイルのパスを保持し、手順3でサブエージェントへ渡す（メインでは Read しない）。

**1件モード:**

```bash
gh issue view {issue_number} --json number,title,body,labels,comments
```

取得した JSON を手順3でサブエージェントへ渡す（DoR 定義・種別プロファイル等の参照ファイルはメインで読み込まず、サブエージェントが自前で Read する）。Issue JSON 自体（`gh` 生出力）のファイル化は本スキルの対象外（原則2＝別 Issue で扱う）。

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

#### Host adapter と完了境界

DoRチェックは定義ファイルの全項目を1件ずつ列挙し、1件でも未充足なら `Not Ready` とする。Claude Codeは `${CLAUDE_PLUGIN_ROOT}` をpluginRootとして解決し、`dev-workflow:issue-refiner` をnative起動する。Codexはhostが解決したpluginRoot（環境変数名を仮定しない絶対パス）を入力として受け、`{pluginRoot}/agents/issue-refiner.md` の全文を `issue,projectDor,pluginRoot,outputContract` とともに独立汎用sub-agentへ注入する。汎用sub-agentを使えない場合はメインループが同じ入力と出力契約で精査するが、全項目評価とNot Ready境界は変えない。起動方式は通常成果へ追加しない。

**1件モード・`--input` モード:**

メイン側で以下のパス・識別子を文字列で組み立て、Agent tool（`subagent_type: dev-workflow:issue-refiner`）を1回起動する（参照ファイル本文の埋め込みは行わない。全件モードと同型のパス渡し）。モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない。

- スキルディレクトリパス（`${CLAUDE_SKILL_DIR}` を展開した実パス）
- プラグインルートパス（Claudeでは`${CLAUDE_PLUGIN_ROOT}`、Codexではhostが渡す解決済み`pluginRoot`の絶対パス。共有DoR・種別プロファイル・振る舞いの不変条件と `{pluginRoot}/agents/issue-refiner.md` の参照に使用）
- プロジェクトルートパス（現在の作業ディレクトリ）
- 精査対象 Issue の情報:
  - **`--input` モード**: 入力 JSON ファイルのパス（サブエージェントが Read する）
  - **1件モード**: 手順2で取得した Issue JSON（`gh` 生出力のファイル化は別 Issue のため、当面はそのまま渡す）

サブエージェントは以下を自分で Read する（全件モードと同一の優先順位）:

1. `{skill_dir}/references/refine-prompt.md`（精査手順本体）
2. プロジェクト固有DoR: `{project_root}/.claude/dor/definition.md`（存在すれば優先）、なければ `{plugin_root}/references/dor-default.md`（プラグイン共有）
3. 種別プロファイル: プロジェクト固有 `{project_root}/.claude/dor/type-profiles.md`（存在すれば優先）、なければ `{plugin_root}/references/issue-type-profiles.md`（プラグイン共有。DoR と同一の優先順位）
4. 出力形式テンプレート: `{skill_dir}/references/output-format-single.md`（`{OUTPUT_FORMAT}` プレースホルダの置換イメージとして適用）
5. `--input` モードの場合、渡された JSON ファイルパスの Issue データ

サブエージェントは精査結果を `output-format-single.md` の形式で返却する。

**全件モード:**

サブエージェントが自分で必要ファイルを Read する形に統一する（メインでのプロンプトベース再生成は行わない）。

1. メイン側で手順2の stdout を行単位で解釈し、1行目を出力ディレクトリ、2行目以降を Issue 番号リストとして取り出す
2. Issue 番号リストを **15件ずつのバッチに分割** する（モデルが直接計算。例: 31件 → 15/15/1 の3バッチ）
3. バッチごとに Agent tool（`subagent_type: dev-workflow:issue-refiner-batch`）を呼び出す（**最大3並列**。モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない）
   - **Bash の for / while で Agent 呼び出しを生成しないこと**（許可プロンプトのパース問題を引き起こすため）
   - **複数の Agent 呼び出しは Agent tool を直接複数回呼び出す形で記述すること**（1メッセージ内で複数 Agent ブロックを並列、バッチ数が3を超える場合は複数メッセージに分けて段階実行）

各サブエージェントには以下のコンテキストを文字列で渡す（ファイル本文の埋め込みは行わない）:

- スキルディレクトリパス（`${CLAUDE_SKILL_DIR}` を展開した実パス）
- プラグインルートパス（`${CLAUDE_PLUGIN_ROOT}` を展開した実パス。共有DoR・振る舞いの不変条件の参照に使用）
- プロジェクトルートパス（現在の作業ディレクトリ）
- Issue ファイルのディレクトリパス（手順2のstdout 1行目）
- 担当 Issue 番号のリスト

サブエージェントは以下を自分で Read する:

1. `{skill_dir}/references/refine-prompt.md`（精査手順本体）
2. プロジェクト固有DoR: `{project_root}/.claude/dor/definition.md`（存在すれば優先）
3. デフォルトDoR: `{plugin_root}/references/dor-default.md`（プラグイン共有。`{plugin_root}` は上で渡したプラグインルートパス）
4. 種別プロファイル: プロジェクト固有 `{project_root}/.claude/dor/type-profiles.md`（存在すれば優先）、なければ `{plugin_root}/references/issue-type-profiles.md`（プラグイン共有。DoR と同一の優先順位）
5. 出力形式テンプレート: `{skill_dir}/references/output-format-batch.md` の「入口: サブエージェント返却形式」節（同節のみを `{OUTPUT_FORMAT}` の置換イメージとして適用する。入口節以外＝出口節・対応表・エラーハンドリング節は適用しない）
6. 担当 Issue 番号それぞれの `{issue_dir}/issue-{number}.json`

サブエージェントは精査結果を構造化データ（YAML/JSON 等）で返却する。

### 4. 出力

サブエージェントの結果を以下の通り取り扱う。

- **1件モード**: サブエージェント（手順3で `${CLAUDE_SKILL_DIR}/references/output-format-single.md` の形式に整形済み）の出力をそのまま表示する。
- **全件モード**: 各サブエージェントの構造化データを集約し、`${CLAUDE_SKILL_DIR}/references/output-format-batch.md` に定義された最終形式で出力する。エラーハンドリング（サブエージェント失敗時の `error` ステータス表示）も同ファイルを参照。
