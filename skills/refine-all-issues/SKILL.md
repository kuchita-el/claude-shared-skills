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
  - リポジトリURL or `--repo <owner/repo>`: 対象リポジトリ（省略時はカレントリポジトリ）
  - `--label <name>`: 特定ラベルのIssueのみ対象（例: `--label bug`）
  - `--limit <n>`: 取得するIssue数を制限（デフォルト: 100）
  - `--force`: スキップ判定を無視して全Issueを再精査
  - `--dry-run`: コメント投稿・ラベル変更を行わず、サマリー出力のみ

引数にGitHub URLが含まれる場合（例: `https://github.com/owner/repo`）、そこから `owner/repo` を抽出して `--repo` として扱う。

## 手順

### 1. 引数の解析とリポジトリ特定

`$ARGUMENTS` からオプションを解析する。`--repo` フラグまたはGitHub URLからリポジトリを特定する。以降の全 `gh` コマンドに `--repo <owner/repo>` を付与する。省略時はカレントディレクトリのリポジトリを使用する。

### 2. DoR定義の読み込み

以下の優先順位でDoR定義を読み込む:

1. **プロジェクト固有**: `{プロジェクトルート}/.claude/dor/definition.md`（存在すれば優先）
2. **デフォルト**: `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`

読み込んだDoR定義の内容を変数として保持する（後でサブエージェントに渡すため）。

### 3. ラベルの準備

`--dry-run` でない場合のみ: `needs-clarification` と `ready-for-work` ラベルが存在しない場合は作成する。

### 4. オープンIssueの一括取得

全Issueの情報を一度のAPIコールで取得する。サブエージェントが個別にAPIを叩く必要をなくすため、本文・ラベル・更新日時・コメントを含めて取得する:

```bash
gh issue list --repo <owner/repo> --state open --json number,title,body,labels,updatedAt,comments --limit <n>
```

`--label` オプションがあれば `--label <name>` を追加する。

### 5. 再精査スキップ判定

各Issueについて再精査が必要か判定する:

**スキップ条件**（`--force` 指定時は無視）: 以下の両方を満たす場合はスキップ

1. 精査コメント（「精査実施: Claude Code」を含む）が存在する
2. 精査コメントの投稿日時 >= IssueのupdatedAt（精査後に更新がない）

スキップしたIssueはサマリーに「skipped」として記録する。

### 6. 各Issueの精査（並列実行）

Agent toolを使用して、精査対象Issueをバッチに分けて並列処理する。

**バッチ分割の指針**: 1バッチあたり10〜15件を目安とする。Agent toolの同時起動数上限を考慮し、最大3バッチを同時に起動する。

サブエージェントにはBash権限がないため、Issue情報とDoR定義をプロンプトに直接埋め込んで渡す。各エージェントに以下を指示:

```
以下のIssueを精査してください。

## DoR（Definition of Ready）定義

{ここにDoR定義の全文を埋め込む}

## 精査対象Issue

{ここに各Issueのnumber, title, body, labelsをJSON形式で埋め込む}

## 精査手順

各Issueについて:

1. サイズ判定（以下の順で判定。最初に該当した条件で確定する）:
   a. ラベル優先: `size:small`, `size:medium`, `size:large` ラベルがあればそのサイズ
   b. Large判定: 本文に「アーキテクチャ」「設計変更」「大規模」を含む、または子Issue参照（`#` + 数字）が3つ以上ある場合はLarge
   c. Small判定: 本文に「バグ」「bug」「typo」「軽微」を含む、または本文500文字未満かつAC2項目以下の場合はSmall
   d. 上記いずれにも該当しない場合はMedium

   **Large判定の子Issue参照カウント**: `#数字` 形式の参照を数える際、「子Issue」「分割先Issue」として参照されているもののみカウントする。「前提Issue」「関連Issue」「依存先」への言及はカウントしない。例えば「前提: #149が完了していること」は子Issue参照ではないが、「子Issue: #166, #167, #168」は子Issue参照としてカウントする。

2. DoRチェック: 判定したサイズに応じたチェック項目を全て評価
3. 精査観点:
   - 不明確な点の洗い出し（曖昧な仕様、複数解釈可能な表現）
   - 決めるべきことのリスト化（設計選択肢、前提条件、UI/UX）
   - スコープの妥当性（1PRで完了可能か、分割が必要か）
   - 受け入れ条件の確認（完了条件・テスト観点が明確か）
   - 依存関係の確認（他Issue、技術的負債）

各Issueについて以下の形式で結果を返してください:
- number: Issue番号
- title: タイトル
- size: Small / Medium / Large
- is_ready: true / false
- has_clarification_needed: true / false
- clarification_items: 確認事項のリスト（なければ空配列）
- comment_body: 確認事項がある場合のみ、Issueコメントとして投稿する内容（なければnull）
```

### 7. 結果の投稿とラベル付与

`--dry-run` の場合はこのステップをスキップし、手順8のサマリー出力に進む。

各Issueに対してコメント投稿とラベル付与を行う。複数行のコメントは Write ツールで一時ファイル（`/tmp/refine-{number}-{timestamp}.md`）に書き出してから `gh issue comment --body-file` で投稿する。

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

### 8. サマリー出力

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
