# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code向けの汎用スキルライブラリ。プロジェクト固有の依存を排除し、どのGitHubリポジトリにもコピーして使える再利用可能なスキル集。

## Local Development Setup

```bash
./setup-local.sh   # claude --plugin-dir . でプラグインとして起動
```

## Architecture

### Repository Structure

- `.claude-plugin/plugin.json` — プラグイン定義（名前・バージョン・説明）
- `.claude-plugin/marketplace.json` — マーケットプレイス定義（プラグイン配布用カタログ）
- `skills/{skill-name}/SKILL.md` — 各スキルの定義ファイル（本体）
- `skills/{skill-name}/references/` — スキルが参照する補助ファイル（テンプレート、デフォルト定義等）
- `agents/{agent-name}.md` — サブエージェント定義（プラグインルートに集約、自動検出される。詳細は ADR-20260525-2）
- `setup-local.sh` — ローカル開発用起動スクリプト（`claude --plugin-dir .` のラッパー）

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
| 計画 | `plan-issue` |
| 開発ループ | `dev-loop` |
| ドメイン設計 | `event-storming` |
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

### ADR（設計判断の記録）

- 設計議論を始める前に `docs/adr/` 配下のADR一覧を確認する
- 設計判断を行ったら、`docs/adr/README.md` の粒度判定基準（4項目チェックリスト）に照らして ADR 化要否を判定する
- 既存ADRと矛盾する設計判断を行う場合は、Superseded 手続きを行う（詳細手順は `docs/adr/README.md`「廃止・上書き手順」参照）

## テスト方針

Discovery（AC作成）とDelivery（テスト設計・TDD実行）の両フェーズで参照する横断的ガイドライン。プロジェクト固有の追加方針（使用フレームワーク、カバレッジ基準、モック方針等）は本節に追記する。

**デフォルトで考慮する観点：**

- 正常系: 主要なユースケースパスの網羅
- 異常系: 不正入力、権限不足、外部サービス障害等
- 境界値: 上限・下限、空・null・ゼロ、型の境界
- 状態遷移: ドメイン構造で定義された遷移パスと禁止遷移の検証

**観点の具体化：** デフォルト観点はplan-issueの検証方針セクションで、選択した技術アプローチに応じたBDD的記述として具体化される。test-designerはこの検証方針セクションをコードレベルのテストケースに変換する。

## ドキュメンテーション戦略

### ディレクトリ構成

ドメイン駆動でドキュメントを組織するプロジェクトの標準構成例（本リポジトリはスキルライブラリのため一部のみ該当）:

```
my-project/
├── CLAUDE.md                              # エージェント向けコンテキスト・規約
├── .claude/
│   ├── skills/                            # 共有スキル（シンボリックリンク）
│   └── agents/                            # プロジェクト固有のサブエージェント
├── docs/
│   ├── problem-statement.md               # 問題定義・Success Metrics
│   ├── big-picture.md                     # システム全体のイベントフロー・コンテキストマップ
│   ├── adr/                               # 設計判断の記録
│   │   └── {番号}-{タイトル}.md
│   ├── plans/                             # 実装プラン（技術設計＋タスク分解）
│   │   └── issue-{番号}.md
│   └── {domain-name}/                     # ドメイン単位でまとめる
│       ├── event-storming.md              # イベント・コマンド・集約・状態遷移
│       ├── domain-modeling.md             # データ型・ワークフロー型定義
│       └── use-cases/                      # ユースケース単位
│           └── {name}/
│               └── spec.md               # ドメインマッピング・AC・外部リソースリンク
├── src/
└── tests/
```

### ストック情報とフロー情報

ドキュメントを「ストック」と「フロー」に区別する。

| 分類 | 性質 | 例 |
|------|------|-----|
| ストック | 蓄積され、繰り返し参照される | problem-statement.md, event-storming.md, domain-modeling.md, ユースケース仕様（spec.md）, ADR |
| フロー | 作業を駆動し、完了後は参照頻度が下がる | Issue, PR, 実装プラン（docs/plans/） |

**原則：ストックとフローは異なる整理原理に従う。** ストック情報はソフトウェアアーキテクチャの構造（ドメイン > ユースケース）で整理する。フロー情報はプロジェクト管理の構造（テーマ > デリバリーアイテム > タスク）で整理する。両者はデリバリーアイテム（Issue）がどのユースケース仕様を参照するか、で接続される。

**原則：フェーズではなくドメインで分類する。** Discovery/Deliveryは時間軸（フェーズ）であり、ディレクトリ構造（空間軸）に反映すべきではない。`docs/discovery/` のようなフェーズ名のディレクトリは作らない。ドメイン構造もユースケース仕様もDiscoveryで作成されるが、Deliveryで継続的に参照・更新される。

### ドキュメント間の結合度

**原則：ドメイン内は密結合OK、ドメイン間は疎結合にする。**

各ドメインのドキュメント（event-storming.md、domain-modeling.md、ユースケース仕様）は同一ドメイン内で密に参照し合ってよい。一方、あるドメインのドキュメントが別ドメインの内部ドキュメントを直接参照してはならない。

ドメイン間の接点は `docs/big-picture.md`（コンテキストマップ）に集約する。各ドメインのドキュメントがドメイン間の関係を知る必要がある場合は、big-picture.mdを参照する。

```
docs/
├── big-picture.md              ← ドメイン間の唯一の接点
├── contract/
│   ├── event-storming.md  ──┐
│   ├── domain-modeling.md ──┤ ドメイン内: 密結合OK
│   └── use-cases/         ──┘
└── billing/
    ├── event-storming.md  ──┐
    ├── domain-modeling.md ──┤ ドメイン内: 密結合OK
    └── use-cases/         ──┘

contract/ ←✕直接参照✕→ billing/     ← ドメイン間: big-picture.md経由
```

この原則により、ドメイン数が増えてもドキュメント間の整合性コストがドメイン数の二乗に比例して増大することを防ぐ。

### <a id="external-tools"></a>外部ツールとの連携

DiscoveryのドキュメントをConfluence等の外部ツールに置くこと自体は問題ない。ただしコーディングエージェントは外部ツールを参照できないため、**エージェントが必要とする情報はリポジトリに転記する**。

```
外部ツール（ソースオブトゥルース）     リポジトリ（エージェント向け）
──────────────────────────────      ──────────────────────────
問題定義（詳細）          →転記→    docs/problem-statement.md
ドメインモデル（詳細）    →転記→    docs/{domain}/
ADR（詳細）               →転記→    docs/adr/
ユーザーストーリー        →起票→    Issue（ACまで記載）
デザインカンプ            →リンク→  ユースケース仕様の外部リソース欄
```

## Adding a New Skill

1. `skills/{skill-name}/SKILL.md` を作成（YAMLフロントマター + 実装仕様）
2. `./setup-local.sh` で起動して動作確認（`/dev-workflow:{skill-name}` でスコープ付き呼び出し）
