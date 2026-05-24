# ADR-20260525-2: サブエージェント定義はプラグインルート agents/ に集約する

## Status

Accepted

## Context

`dev-workflow` プラグインのサブエージェント定義（code-reviewer / refactorer / test-designer / test-spec-validator / plan-reviewer）は、各スキル配下 `skills/*/agents/*.md` にプロンプトテンプレートとして配置していた。`plugin.json` にエージェント登録はなく、Claude Code 公式のサブエージェント自動検出機構を使っていない。

この方式では、`dev-loop` の各 Phase でメインエージェントが定義ファイルを `Read` してからプロンプトに埋め込んで `Agent` ツールに委任する必要があり、以下の問題が生じていた（#217）。

- 実行毎に Phase 数分（最低4回）の余分な `Read` ツール呼び出しが発生する
- SKILL.md の指示がインライン展開を明示しておらず、メイン側 `Read` に加えサブエージェント側も定義ファイルを再 `Read` する二重読みが観測された
- 作業ディレクトリ外を含むツール呼び出しで許可プロンプトが発生する環境ではワークフロー中断要因になる
- ログが冗長化しデバッグ容易性が下がる

参考実装の `pr-review-toolkit` プラグインを確認したところ、プラグインルート直下 `agents/` に `*.md` を置くだけで全ファイルがサブエージェントとして自動登録され、`plugin.json` への明示記述は不要であった（frontmatter は `name`, `description`, `model`, `color`）。

## Decision

`dev-workflow` プラグイン配下の全サブエージェント定義は、各スキル配下 `skills/*/agents/` ではなくプラグインルート `agents/` に配置し、Claude Code 公式のサブエージェント自動検出機構を活用する。

- 全サブエージェント定義を `agents/*.md` に集約し、YAML frontmatter を `name`, `description`, `model`, `color` 形式に統一する
- スキルからの委任は `subagent_type: dev-workflow:<name>` 形式で行い、メインエージェントによる定義ファイルの `Read` を排除する
- `Agent` ツールが使えないインライン経路（サブエージェントからの再帰呼び出し等）では、定義内容をプロンプト本文へ埋め込んで実行し、サブエージェント側からの定義ファイル再 `Read` は行わない
- 将来追加するサブエージェントも本原則に従い `agents/` 直下に配置する

## Consequences

- メインエージェントによる定義ファイル `Read` および二重読みが解消され、ツール呼び出しと許可プロンプトの中断が減る
- サブエージェント定義の配置が一箇所に集約され、スキルごとに分散することによる将来の乖離リスクが下がる
- スキルディレクトリ単独では「どのサブエージェントを使うか」が見えなくなる。これは各 SKILL.md の `subagent_type: dev-workflow:<name>` 記述で補う
- 自動検出・登録の挙動は Claude Code 側の仕様に依存する。将来この機構が変わった場合は本 ADR を再検討する
- インライン経路の文言（案2）はフォールバック専用として SKILL.md に残す

## 関連ADR

Related: ADR-20260525-subagent-claude-md-injection（同じくサブエージェント起動時の余分な Read を扱う）。関連Issue: #217, #216
