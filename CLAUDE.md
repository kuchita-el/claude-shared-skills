# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code向けの汎用スキルライブラリ。プロジェクト固有の依存を排除し、どのGitHubリポジトリにもコピーして使える再利用可能なスキル集。

## Local Development Setup

```bash
./setup-local.sh   # claude --plugin-dir ./plugins/dev-workflow でプラグインとして起動
```

## Architecture

### Repository Structure

- `.claude-plugin/marketplace.json` — マーケットプレイス定義（プラグイン配布用カタログ。リポルート維持。`source: "./plugins/dev-workflow"`）
- `plugins/dev-workflow/.claude-plugin/plugin.json` — プラグイン定義（名前・バージョン・説明）
- `plugins/dev-workflow/skills/{skill-name}/SKILL.md` — 各スキルの定義ファイル（本体）
- `plugins/dev-workflow/skills/{skill-name}/references/` — スキルが参照する補助ファイル（テンプレート、デフォルト定義等）
- `plugins/dev-workflow/references/` — 複数スキルが共有する参照ファイル（DoRデフォルト定義等。`${CLAUDE_PLUGIN_ROOT}/references/` で参照。詳細は ADR-20260604）
- `plugins/dev-workflow/agents/{agent-name}.md` — サブエージェント定義（プラグインルートに集約、自動検出される。詳細は ADR-20260525-2）
- `setup-local.sh` — ローカル開発用起動スクリプト（`claude --plugin-dir ./plugins/dev-workflow` のラッパー）

### Skill Definition Format

各スキルは `plugins/dev-workflow/skills/{name}/SKILL.md` に以下の形式で定義する:

```markdown
---
description: "スキルの1行説明"
allowed-tools:
  - Read
  - Bash(gh issue view*)    # Bashはコマンドパターンで粒度制御
  - AskUserQuestion
---

# スキル名

実装仕様（目的・引数・手順・出力形式・注意事項）
```

**`allowed-tools` の原則**: 必要最小限のツールのみ許可する。Bashは `Bash(コマンドパターン*)` でワイルドカード指定し、スキルが実行できるシェルコマンドを制限する。

### Skill Categories

| カテゴリ | スキル |
|---|---|
| Issue管理 | `create-issue`, `refine-issue` |
| 計画 | `plan-issue` |
| 開発ループ | `dev-loop` |
| ドメイン設計 | `event-storming` |
| 依存関係 | `dependency-check` |

### DoR Framework

`create-issue`（作成時の前倒し充足）と `refine-issue`（作成後の精査）が同一のDoR定義を共有参照する。読み込み優先順位:

1. `{project}/.claude/dor/definition.md`（プロジェクト固有）
2. `plugins/dev-workflow/references/dor-default.md`（プラグイン共有のデフォルト。`${CLAUDE_PLUGIN_ROOT}/references/` で参照。詳細は ADR-20260604）

Issueサイズ（Small/Medium/Large）に応じてチェック項目が段階的に増える。

## Conventions

- ドキュメントおよびスキル内のコメントは日本語で記述する
- スキルはGitHub CLI (`gh`) のみに依存し、プロジェクト固有のツールには依存しない
- 複数行コンテンツをCLIに渡す際は Write ツールで一時ファイル（`/tmp/filename-{timestamp}.md`）に書き出してから `--body-file` 等で渡す（`allowed-tools` のBashパターンがヒアドキュメント等の複雑なコマンドにマッチしないため）
- スキルの出力形式（テーブル、レポートなど）は各SKILL.md内に明示的に定義する

## Rules

- 議論・評価・設計を求められた場合、ファイルの編集を始めない。明示的な承認を得てから編集すること
- スキル定義（SKILL.md）は最小限に保つ。冗長なコメント・不要なツール権限を追加しない。特に `AskUserQuestion` はスキル内に対話パスが存在する場合のみ許可する
- 計画や設計の議論中にユーザーが決定を下したら、即座に計画ドキュメントに反映する。古い前提のまま進めない

### ADR（設計判断の記録）

- 設計議論を始める前に `docs/adr/` 配下のADR一覧を確認する
- 設計判断を行ったら、`docs/adr/README.md` の粒度判定基準（4項目チェックリスト）に照らして ADR 化要否を判定する
- 既存ADRと矛盾する設計判断を行う場合は、Superseded 手続きを行う（詳細手順は `docs/adr/README.md`「廃止・上書き手順」参照）

## Adding a New Skill

1. `plugins/dev-workflow/skills/{skill-name}/SKILL.md` を作成（YAMLフロントマター + 実装仕様）
2. `./setup-local.sh` で起動して動作確認（`/dev-workflow:{skill-name}` でスコープ付き呼び出し）
