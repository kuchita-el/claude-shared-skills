# claude-shared-skills

Claude Code向けの汎用スキル集です。プロジェクト固有の依存を排除し、どのプロジェクトでも利用できるようにしています。

## 導入方法

### 1. スキルのコピー

使いたいスキルを `.claude/skills/` にコピーしてください:

```bash
# 例: 全スキルをコピー
cp -r skills/* /path/to/your-project/.claude/skills/

# 例: 特定のスキルのみコピー
cp -r skills/dev-loop /path/to/your-project/.claude/skills/
```

### 2. DoR定義のカスタマイズ（オプション）

`/refine-issue` はDoR定義を参照します。スキル同梱のデフォルト定義（`skills/refine-issue/references/dor-default.md`）がそのまま使われますが、プロジェクトに合わせてカスタマイズする場合は `.claude/dor/definition.md` を配置してください:

```bash
mkdir -p /path/to/your-project/.claude/dor
cp skills/refine-issue/references/dor-default.md /path/to/your-project/.claude/dor/definition.md
# 必要に応じて編集
```

## スキル一覧

### Issue管理

| スキル | コマンド | 説明 |
|---|---|---|
| refine-issue | `/refine-issue 123` | Issueの準備状態を精査しレポート（1件精査・全件一括精査の両方に対応） |

### 開発ループ

| スキル | コマンド | 説明 |
|---|---|---|
| dev-loop | `/dev-loop 10` | Issue・計画・レビュー指摘を起点に、実装→セルフレビュー→修正→PR作成を自動化する汎用開発ループ |

### 依存関係

| スキル | コマンド | 説明 |
|---|---|---|
| dependency-check | `/dependency-check react` | 依存パッケージ更新のBreaking Changes・互換性・コード影響を自動分析 |

## カスタマイズポイント

### DoR定義

`/refine-issue` はDoR（Definition of Ready）定義を参照します。

**読み込み優先順位:**

1. `{プロジェクトルート}/.claude/dor/definition.md`（プロジェクト固有）
2. スキル同梱のデフォルト（`skills/refine-issue/references/dor-default.md`）

プロジェクトに合わせたチェック項目にカスタマイズする場合は、`.claude/dor/definition.md` を作成してください。

## 開発者向け: このリポジトリでスキルを使う

このリポジトリ内で開発中のスキルを試すには、セットアップスクリプトを実行してください:

```bash
./setup-local.sh
```

`.claude/skills/` 内に各スキルへのシンボリックリンクが作成され、スキルコマンドがそのまま使えるようになります。スキルを新規追加した場合も再実行すればリンクが追加されます。壊れたリンクは自動的に清掃されます。

## ライセンス

プロジェクト内で自由にご利用ください。
