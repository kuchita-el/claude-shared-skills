# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code向けの汎用スキルライブラリ。プロジェクト固有の依存を排除し、どのGitHubリポジトリにもコピーして使える再利用可能なスキル集。

## Local Development Setup

```bash
./setup-local.sh   # .claude/skills/ にシンボリックリンクを作成
```

新しいスキルを追加した場合も再実行すればリンクが追加される。

## Architecture

### Repository Structure

- `skills/{skill-name}/SKILL.md` — 各スキルの定義ファイル（本体）
- `skills/{skill-name}/references/` — スキルが参照する補助ファイル（テンプレート、デフォルト定義等）
- `setup-local.sh` — ローカル開発用シンボリックリンク作成スクリプト

### Skill Definition Format

各スキルは `skills/{name}/SKILL.md` に以下の形式で定義する:

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
| Issue管理 | `refine-issue` |
| 開発ループ | `dev-loop` |
| PR・レビュー | `pr-comment` |
| 依存関係 | `dependency-check` |

### DoR Framework

`refine-issue` はDoR定義を参照する。読み込み優先順位:

1. `{project}/.claude/dor/definition.md`（プロジェクト固有）
2. `skills/refine-issue/references/dor-default.md`（スキル同梱のデフォルト）

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

## Adding a New Skill

1. `skills/{skill-name}/SKILL.md` を作成（YAMLフロントマター + 実装仕様）
2. `./setup-local.sh` を再実行してシンボリックリンクを更新
3. Claude Codeで `/{skill-name}` として動作確認
