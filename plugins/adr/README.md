# adr プラグイン

ADR（アーキテクチャ決定記録）の運用機構を配布する Claude Code / Codex プラグイン。どの GitHub リポジトリにも導入でき、ADR の drift-lint・有効性 index 生成・ライフサイクル操作を提供する。

## 提供物

- **drift-lint（`scripts/lint-adr.sh`）**: ADR corpus が満たすべき機械検査可能な不変条件を検査する。front-matter スキーマ（状態語彙・有効性語彙・遷移整合）、有効性 index との整合、ADR 間参照（上書き関係の双方向性、`Related:` の参照先の生存性・実在性）、ファイル名と識別子の規約適合および識別子の一意性と H1 見出しとの整合が対象。
- **有効性 index 生成（`scripts/gen-adr-index.sh`）**: `validity: 有効` の ADR を抽出して index を生成する。
- **識別子の発番（`scripts/next-adr-id.sh`）**: 起票時刻（分粒度・ローカル時刻）と同一時刻部内の連番から、次に起票する ADR の識別子 `ADR-YYYYMMDDHHMM-NN` を発番する。連番の算出対象を同一時刻部のファイルに限るため、並行するブランチがそれぞれ発番しても識別子が衝突しない。
- **固定題材集合の実行支援（`scripts/adr-scoping-cases.sh`）**: 判定手続きを定めた文書を被テスト対象とし、固定した題材を通して帰結の差を見るための検査器。`prompt` / `validate` / `report` / `derive` / `crosscheck` / `validate-returns` を提供し、保存済みJSONの実測事実から点数を算出・一致検査・全件型検査する。題材集合ディレクトリ、返却ディレクトリ、対象文書パスは引数で受け、既定値を持たない（理由はスクリプト冒頭のコメントに置く）。**本スクリプトは manage-adr スキルからも commit ゲートからも呼ばれず、判定手続き文書を改訂する担い手が手で起動する。** 題材集合そのものは各リポジトリが自前で用意する。
- **commit 前ゲート（`hooks/`）**: `git commit` 時に PreToolUse フックとして drift-lint を実行し、違反があれば commit をブロックする（exit 2）。対象リポジトリに ADR ディレクトリが存在しない場合は何もしない（no-op）。
- **manage-adr スキル（`skills/manage-adr/`）**: ADR の起票・承認・上書き・廃止・却下・編集・分割を対話的に行うライフサイクル操作スキル。

## ホスト差分

両ホストの成果契約は、明示的に `lint-adr.sh`、`gen-adr-index.sh`、
`next-adr-id.sh` を実行して結果を確認することです。Claude Codeでは追加で
PreToolUseのcommitゲートを利用できます。Codexには現時点で同等のplugin単位
commit hookがないため、明示lintを必須とする `degraded` 互換です。

Codexがplugin単位のhook/policy callbackとブロック結果を提供した時点を、
host adapterへ移行するトリガーとします。移行まではホスト別のworkflowを複製しません。

同梱スクリプトのテストランナーと fixture は本配布物に含めない。配布物が持つのは検査器のみであり、検査用データの同梱と、スクリプトが自環境で動くことの確認は本配布物の責務ではない。

## 導入

ローカル marketplace 経由（推奨）、または `claude --plugin-dir /path/to/plugins/adr` で読み込む。恒常有効化する場合は導入先リポジトリの `.claude/settings.json` の `enabledPlugins` に登録する。

## ADR ディレクトリの指定（`ADR_DIR`）

`lint-adr.sh` / `gen-adr-index.sh` / `next-adr-id.sh` は対象の ADR ディレクトリ（前2者は検査対象、`next-adr-id.sh` は既存 ADR の列挙対象）を第1引数（`ADR_DIR`）で受け取り、**既定は `docs/adr`**。導入先が別配置（例 `architecture/decisions`）を使う場合は引数で上書きする。commit ゲートは既定の `docs/adr` を対象に実行する。

> 導入先固有設定を宣言ファイルで駆動する full config 方式の override は本プラグインのスコープ外（別途対応）。現時点の override 手段は `ADR_DIR` 引数のみ。
