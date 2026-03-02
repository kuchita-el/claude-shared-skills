# claude-shared-skills

Claude Code向けの汎用スキル集です。プロジェクト固有の依存を排除し、どのプロジェクトでも利用できるようにしています。

## 導入方法

### 1. スキルのコピー

使いたいスキルを `.claude/skills/` にコピーしてください。`/refine-issue`、`/ready-check`、`/refine-all-issues` を使う場合は `defaults/` ディレクトリも合わせてコピーしてください:

```bash
# 例: 全スキルとデフォルト定義をコピー
cp -r skills/* /path/to/your-project/.claude/skills/
cp -r defaults /path/to/your-project/.claude/skills/

# 例: 特定のスキルのみコピー
cp -r skills/fix-review /path/to/your-project/.claude/skills/
```

### 2. DoR定義のカスタマイズ（オプション）

`/refine-issue`、`/ready-check`、`/refine-all-issues` はDoR定義を参照します。デフォルト定義（`defaults/dor/definition.md`）がそのまま使われますが、プロジェクトに合わせてカスタマイズする場合は `.claude/dor/definition.md` を配置してください:

```bash
mkdir -p /path/to/your-project/.claude/dor
cp defaults/dor/definition.md /path/to/your-project/.claude/dor/definition.md
# 必要に応じて編集
```

### 3. daily-prepの設定（オプション）

`/daily-prep` を使う場合、設定ファイルをコピーして編集してください:

```bash
cp skills/daily-prep/config.yaml.example /path/to/your-project/.claude/skills/daily-prep/config.yaml
```

## スキル一覧

### Issue管理

| スキル | コマンド | 説明 |
|---|---|---|
| refine-issue | `/refine-issue 123` | 作業開始前にIssueを精査し、不明点の洗い出し・分割提案を行う |
| ready-check | `/ready-check 123` | DoR（Definition of Ready）に基づくIssue Ready判定 |
| refine-all-issues | `/refine-all-issues` | 全オープンIssueを一括精査し、確認事項をコメント投稿・ラベル付与 |
| create-issue | `/create-issue` | 議論内容からGitHub Issueを作成（コード編集制限付き） |
| triage-issues | `/triage-issues` | 優先度の高いIssueをピックアップして提案 |

### PR・レビュー

| スキル | コマンド | 説明 |
|---|---|---|
| fix-review | `/fix-review` | PRレビュー指摘の修正→検証→コミットを自動化するフィックスパイプライン |
| pr-comment | `/pr-comment 123` | レビュー結果をGitHubのPRにインラインコメントとして投稿 |

### スプリント管理

| スキル | コマンド | 説明 |
|---|---|---|
| daily-prep | `/daily-prep` | デイリースクラム前のIssue/PR状況一覧表示 |

### インシデント対応

| スキル | コマンド | 説明 |
|---|---|---|
| incident-triage | `/incident-triage [エラーメッセージ]` | エラーの重大度・影響範囲を判断し、対応優先度の決定を支援 |
| incident-investigate | `/incident-investigate [エラーメッセージ]` | エラーの発生箇所を詳細に調査し、根本原因の特定を支援 |

### その他

| スキル | コマンド | 説明 |
|---|---|---|
| adr-create | `/adr-create` | ADR（Architecture Decision Record）の作成を対話形式で支援 |

## カスタマイズポイント

### DoR定義

`/refine-issue`、`/ready-check`、`/refine-all-issues` はDoR（Definition of Ready）定義を参照します。

**読み込み優先順位:**

1. `{プロジェクトルート}/.claude/dor/definition.md`（プロジェクト固有）
2. `{プロジェクトルート}/.claude/skills/defaults/dor/definition.md`（デフォルト）

プロジェクトに合わせたチェック項目にカスタマイズする場合は、`.claude/dor/definition.md` を作成してください。

### daily-prep設定

`/daily-prep` は `.claude/skills/daily-prep/config.yaml` で設定をカスタマイズできます。

| 設定キー | デフォルト値 | 説明 |
|---|---|---|
| `issueTrackers` | `[{type: github}]` | 課題管理システム（現在はGitHubのみサポート） |
| `blockers.reviewPendingThresholdHours` | `24` | レビュー待ち放置と判定する閾値（時間） |

設定ファイルがない場合はデフォルト値で動作します。

## 対象外スキル

以下のスキルはプロジェクト固有の依存があるため、本リポジトリには含まれていません:

- **dep-check**: シェルスクリプトがパッケージマネージャに依存しているため、PM抽象化と合わせて後続対応予定

## ライセンス

プロジェクト内で自由にご利用ください。
