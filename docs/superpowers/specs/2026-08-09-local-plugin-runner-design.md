# Claude Code / Codex ローカルプラグイン実行スクリプト設計

## 目的

main ブランチへマージする前のプラグインを Claude Code と Codex の双方で検証できるようにする。スクリプト名から対象ランタイムとローカル開発用途が分かり、ランタイム固有の引数を制限なく渡せることを重視する。

## インターフェース

- `run-claude-local.sh [claude arguments...]`
- `run-codex-local.sh [codex arguments...]`

両スクリプトは受け取った引数を順序と値を変えず、それぞれ `claude` / `codex` へ渡す。

## Claude Code の実行経路

`run-claude-local.sh` はリポジトリルートへ移動し、`plugins/dev-workflow`、`plugins/adr`、`plugins/writing` を `--plugin-dir` で指定して Claude Code を起動する。利用者の引数は固定の `--plugin-dir` 群より後ろへ渡す。

## Codex の実行経路

`run-codex-local.sh` は次の順序で処理する。

1. リポジトリのローカル marketplace が未登録なら登録する。
2. `dev-workflow`、`growth`、`adr`、`writing` が未導入ならインストールする。
3. `superpowers@openai-curated` が未導入ならインストールする。
4. 利用者の全引数を渡して Codex を起動する。

各インストールは既存状態を確認してから行い、繰り返し実行できるようにする。Superpowers はオプションではなく必須とする。

## 命名と移行

既存の `setup-local.sh` と PR #702 で追加した `setup-codex.sh` は、それぞれ `run-claude-local.sh` と `run-codex-local.sh` へ改名する。旧名の互換ラッパーは残さず、リポジトリ内の参照を新名称へ更新する。

## 検証

- 両スクリプトのシェル構文を検証する。
- 偽の `claude` / `codex` コマンドを使い、引数透過、固定引数、インストール順序、既存プラグインのスキップを確認する。
- リポジトリ全体のテストとスキル検査を実行する。
