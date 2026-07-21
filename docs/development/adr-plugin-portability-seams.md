# ADR プラグイン可搬化の継ぎ目リスト

ADR 運用機構を独立プラグイン `plugins/adr/` へ抽出（#492/#493）する過程で判明した、「何がプロジェクト固有で何が可搬か」の分界（継ぎ目）を記録する。#492 の成果物であり、#493 のレイヤ上書き（プラグイン default / プロジェクト override）設計の入力となる。

各エントリは **状態** を持つ:

- **解消済**: 本抽出（#492 前倒し分）で解決した
- **設計依存**: プラグインの設計で吸収した（override 余地は #493 で扱う）
- **未確認**: fresh session / 別リポ試用（Phase B・利用者実施）での実地確認を要する

## 確定済みの継ぎ目（#492 起票時に実測、抽出で対処）

| # | 継ぎ目 | 状態 | 対処 |
|---|---|---|---|
| 1 | commit ゲートが ADR 無関係の検査（`validate-skills.sh`）を巻き込む | 解消済 | プラグイン同梱ゲート（`adr-commit-gate`）は `lint-adr` のみ実行。`validate-skills` は repo-root ゲートに残置 |
| 2 | ゲートが `CLAUDE_PROJECT_DIR` に依存 | 設計依存 | `adr-commit-gate` は `CLAUDE_PROJECT_DIR` を優先し、未設定なら cwd へフォールバック。プラグイン PreToolUse フックでの `CLAUDE_PROJECT_DIR` 供給は docs 未明記（#11 参照） |
| 3 | `docs/adr/README.md` がプラグインへ越境リンク | 解消済 | 越境リンクを `plugins/adr/skills/manage-adr/...` へ張替え |
| 4 | スキルの `allowed-tools` がスクリプトのパスを縛る | 解消済 | invocation を `${CLAUDE_PLUGIN_ROOT}/scripts/...` へ。`allowed-tools` は `Bash(bash *scripts/lint-adr.sh*)` の glob で追随 |
| 5 | `lint-adr.sh` と `gen-adr-index.sh` が同居必須（`$(dirname "$0")` 解決） | 設計依存 | 両者を `plugins/adr/scripts/` へ同居移設し維持 |
| 6 | スキルが本リポの ADR 実体を「生きた正本」として参照 | 解消済 | #515 完了で正本を README/manage-adr へ反転済み。抽出時の残 backlink は provenance として削除（#8） |

## 抽出中に判明した継ぎ目

| # | 継ぎ目 | 状態 | 対処 |
|---|---|---|---|
| 7 | `test-lint-adr.sh` の AC5 surface が host 固有 `docs/adr/README.md` と可搬な manage-adr スキル面を跨ぐ | 解消済 | README を surface から除外し manage-adr surface を plugin 相対へ rebase（回帰テストは新設しない＝現状 legacy 言及は散文で AC5 の見出し形検査が非発火のため） |
| 8 | KEEP 資産（scripts・manage-adr）内に本リポ ADR/Issue 番号の provenance backlink が散在。#522 のレイヤ4追加で `lint-adr.sh` コメントの参照が増加 | 対処中（A.12） | Issue/ADR 番号を削除し説明散文は残す。`plugins/adr/` 内に dangling 参照 0 件を目標 |
| 9 | `test-lint-adr.sh` の `run_real_corpus_clean`（#522 追加）が本リポの実 `docs/adr` を lint | 解消済 | 可搬テストから除去。実 corpus の保護は commit ゲートが担う |
| 10 | `test-lint-adr.sh` の #522(AC5) が `lint-adr.sh` ヘッダに `ADR-20260720-4` の明記を強制（provenance を要求するテスト） | 対処中（A.12） | provenance 削除に併せてアサートを汎用化 |
| 11 | ローカルプラグインを消費側リポの `.claude/settings.json` `enabledPlugins` で常時有効化する手段が docs 未明記 | 未確認 | J10 案A の実現可否。fresh session での実地確認を要する。不可なら repo-root shim（案B）へフォールバック |
| 12 | `gen-adr-index.sh` の生成コメントが `scripts/` パスを焼き込み、生成物 `index.md` に載る | 対処中（A.12） | パスを汎用化し index を再生成 |

## 未反映（後続・別リポ試用で扱う）

- **ADR_DIR の override**: `lint-adr.sh` / `gen-adr-index.sh` は `ADR_DIR`（既定 `docs/adr`）を引数で受け上書き可能だが、宣言ファイル駆動の full config override は #493 のレイヤ上書きへ。
- **ADR 本文の歴史的記述**: ADR-20260711-3 決定5 が drift-lint の配置（`scripts/lint-adr.sh`・`.claude/settings.json` PreToolUse）を記述しており、移設で配置が変わる。amend 要否は抽出決定として別途判定する。
- **別リポ試用（Phase B・利用者実施）**: 導入・運用時に書き換えを強いられた未知の継ぎ目を、利用者が本リストへ追記する。
