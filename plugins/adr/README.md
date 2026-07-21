# adr プラグイン

ADR（アーキテクチャ決定記録）の運用機構を配布する Claude Code プラグイン。どの GitHub リポジトリにも導入でき、ADR の drift-lint・有効性 index 生成・ライフサイクル操作を提供する。

## 提供物

- **drift-lint（`scripts/lint-adr.sh`）**: ADR の front-matter スキーマ検証（状態語彙・有効性語彙・遷移整合）、有効性 index との整合、`Related:`／パーク欄の参照生存性・実在性を検査する。
- **有効性 index 生成（`scripts/gen-adr-index.sh`）**: `validity: 有効` の ADR を抽出して index を生成する。
- **commit 前ゲート（`hooks/`）**: `git commit` 時に PreToolUse フックとして drift-lint を実行し、違反があれば commit をブロックする（exit 2）。対象リポジトリに ADR ディレクトリが存在しない場合は何もしない（no-op）。
- **manage-adr スキル（`skills/manage-adr/`）**: ADR の起票・承認・上書き・廃止・却下・編集・分割を対話的に行うライフサイクル操作スキル。

## 導入

ローカル marketplace 経由（推奨）、または `claude --plugin-dir /path/to/plugins/adr` で読み込む。恒常有効化する場合は導入先リポジトリの `.claude/settings.json` の `enabledPlugins` に登録する。

## ADR ディレクトリの指定（`ADR_DIR`）

`lint-adr.sh` / `gen-adr-index.sh` は検査対象の ADR ディレクトリを第1引数（`ADR_DIR`）で受け取り、**既定は `docs/adr`**。導入先が別配置（例 `architecture/decisions`）を使う場合は引数で上書きする。commit ゲートは既定の `docs/adr` を対象に実行する。

> 導入先固有設定を宣言ファイルで駆動する full config 方式の override は本プラグインのスコープ外（別途対応）。現時点の override 手段は `ADR_DIR` 引数のみ。
