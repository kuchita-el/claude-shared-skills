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
- `skills/defaults/dor/definition.md` — DoR（Definition of Ready）のデフォルトテンプレート
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
| Issue管理 | `refine-issue`, `refine-all-issues` |
| PR・レビュー | `fix-review`, `pr-comment` |

### DoR Framework

`refine-issue`, `refine-all-issues` はDoR定義を参照する。読み込み優先順位:

1. `{project}/.claude/dor/definition.md`（プロジェクト固有）
2. `{project}/.claude/skills/defaults/dor/definition.md`（デフォルト。`skills/defaults/` から配置）

Issueサイズ（Small/Medium/Large）に応じてチェック項目が段階的に増える。

## Conventions

- ドキュメントおよびスキル内のコメントは日本語で記述する
- スキルはGitHub CLI (`gh`) のみに依存し、プロジェクト固有のツールには依存しない
- 複数行コンテンツをAPIに渡す際は `/tmp/filename-{timestamp}.md` に一時ファイルとして書き出す
- スキルの出力形式（テーブル、レポートなど）は各SKILL.md内に明示的に定義する

## Adding a New Skill

1. `skills/{skill-name}/SKILL.md` を作成（YAMLフロントマター + 実装仕様）
2. `./setup-local.sh` を再実行してシンボリックリンクを更新
3. Claude Codeで `/{skill-name}` として動作確認
