---
id: MEM-202611211524-01
type: experience
title: サブエージェントの定義の model と effort が効いたかは、子プロセスのセッションの記録で確かめられ、主のモデルを別の系列にすると出力の流れだけでも model を見分けられる
author: ai
verification: verified
confidence: medium
applies-when: 配布プラグインのサブエージェントが、定義の front-matter どおりの水準で動いたかを確かめるとき
sources:
  - 2026-11-21、記録を突き合わせるスキルを足した作業で、スキルを子プロセス（claude -p。Claude Code 2.1.330、Linux のコンテナ）で1回起動し、出力とセッションの記録を読んで観測した
created: 2026-11-21
updated: 2026-11-21
---

## 観測したこと

- プラグインのディレクトリを `--plugin-dir` で指し、主のモデルを `--model` でサブエージェントの定義と別の系列にして、スキルを `-p` で起動した。出力は `--output-format stream-json --verbose` でファイルへ受けた。
- 出力の流れのうち、`parent_tool_use_id` を持つ行の `.message.model` は、定義の `model` の系列だった。主の行は、`--model` で指した系列だった。
- `effort` は、出力の流れには出なかった。セッションの記録の `subagents/agent-*.jsonl` の `.effort` に、定義の値が出た。置き場は、`~/.claude/projects/<作業ディレクトリの / を - に置き換えたもの>/<セッションの識別子>/` である。
- 同じ場所の `agent-*.meta.json` の `.agentType` は、`<プラグイン名>:<定義の名前>` だった。
- 許可を拒まれた道具の呼び出しは、出力の最後の `result` の行の `permission_denials` に並ぶ。この実行では0件だった。

## 言えること

サブエージェントの実効の水準を確かめるときは、主のモデルを定義と別の系列にして子プロセスで1回起動する。`model` は出力の流れで、`effort` はセッションの記録で読む。主のモデルが定義と同じ系列だと、出力の流れからは、定義が効いたのか既定を継いだのかを分けられない。

## 当てはまらない場合と、確かめていないこと

- eval の実行系（`claude plugin eval`）の trace には、`effort` が出ない。そこで見られるのは `model` だけである。これは、この作業では実行して確かめていない。別の文脈の報告に拠る。
- セッションの記録の置き場と項目の名前は、Claude Code の版で変わりうる。1回の観測である。
- Codex では確かめていない。
