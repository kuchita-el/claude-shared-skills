# CLAUDE.md

## Project Overview

Claude Code 向けの汎用スキルライブラリ。プロジェクト固有の依存を排除し、どの GitHub リポジトリへもコピーして使える再利用可能なスキルを配布する。

## 転換期間中の開発方式

本リポジトリの開発方式の背骨は `dev-workflow` の工程から Spec-as-Code 方式へ転換中である（ADR-202609110017-01。方式の設計は `docs/development/spec-as-code/design.md`）。

- 統治機構の縮小作業と新方式プラグインの立ち上げは、`dev-workflow` の工程（Issue・プラン・レビュー契約）を通さず直接コミットで回す。縮小作業は Issue 化しない
- 存続配布物（growth / domain-design / dependency-insight / adr / writing）の機能変更はこの射程に含めず、従来どおりレビュー契約を通す。利用者へ配る資産の変更が無レビューで入ることを避ける
- commit ゲート（`scripts/hooks/pre-commit-gate.sh`）は退行検知として最後まで残す。退行検知はレビュー契約の代替にならない
- 転換期間は、新方式プラグインが本リポジトリ自身の開発を回せるようになった時点で終える

## Local Development Setup

```bash
./run-claude-local.sh --model opus   # marketplace の全 plugin を読み込んで起動
./run-codex-local.sh --model gpt-5.6 # Codex 用プラグインと必須の Superpowers を導入して起動
mise trust && mise install           # チェックアウト（worktree 含む）ごとに一度。bats を版固定で導入する
bash scripts/run-tests.sh            # テストと検査器を一括実行する
```

テストの実行経路（自動起動の射程・手動実行・失敗時の読み方）は `docs/development/test-execution.md` が定める。

## Repository Structure

- `.claude-plugin/marketplace.json` — 配布カタログ。リポジトリルートに維持する
- `plugins/{plugin}/.claude-plugin/plugin.json` — プラグイン定義。版は持たずコミット SHA が担う（ADR-202609061416-01）
- `plugins/{plugin}/skills/{skill}/SKILL.md` — スキル本体。テンプレート・判定基準等の補助ファイルは同階層の `references/` へ置く
- `plugins/{plugin}/references/` — 複数スキルが共有する参照ファイル。`${CLAUDE_PLUGIN_ROOT}/references/` で参照する（ADR-202606040737-01）
- `plugins/{plugin}/agents/{agent}.md` — サブエージェント定義。プラグインルートに集約し自動検出させる（ADR-202605250838-01）
- `run-claude-local.sh` / `run-codex-local.sh` — ローカル起動ラッパー（引数を透過する）

配布物は `adr`（ADR 運用の検査・発番・ライフサイクル操作。設計・改修時の規律は `docs/development/adr-plugin-design-guideline.md` が定める）／`growth`（学習シグナルの捕捉・蒸留・昇格）／`domain-design`（event-storming / domain-modeling）／`dependency-insight`（dependency-check）／`writing`（intent 執筆支援）の5件と、退役予定の `dev-workflow`（ADR-202609110017-01 決定1）。

## スキルの追加と定義形式

1. 追加先の配布物を選び `plugins/{plugin}/skills/{skill-name}/SKILL.md` を作成する。退役予定の `dev-workflow` へ新規スキルを追加しない
2. `./run-claude-local.sh --model opus` で起動し `/{plugin}:{skill-name}` で動作確認する

```markdown
---
description: "スキルの1行説明"
allowed-tools:
  - Read
  - Bash(gh issue view*)    # Bash はコマンドパターンで粒度制御
---

# スキル名

実装仕様（目的・引数・手順・出力形式・注意事項）
```

`allowed-tools` は必要最小限に絞り、Bash は `Bash(コマンドパターン*)` で実行できるシェルコマンドを制限する。`AskUserQuestion` はスキル内に対話パスが存在する場合のみ許可する。ツール名から自明な説明コメントは付さない。

## スキル設計の token 規律

- `description` は 200 字程度を目安、最長 300 字。同義語のトリガーワードを羅列せず代表 3〜5 個に絞る
- `SKILL.md` は frontmatter を除いた本文 170 行を上限の目安とし、超える場合は詳細手順・テンプレート・判定基準を `references/` へ分離する
- 分離した参照は `${CLAUDE_SKILL_DIR}/references/{filename}.md` 形式で on-demand に読み、SKILL.md 本体には骨格とポインタだけを残す
- 重い精査・調査・複数件の一括処理はサブエージェント並列化を既定とする。サブエージェントへはコンテキストを文字列で渡し、ファイル本文を埋め込まない（必要なら委譲先が Read する）

上は作成時（静的）のフットプリント規律である。スキル実行中にメイン context へ何を載せ／載せないかは `docs/references/context-budget.md` が定める。

## 成果物の分量と作業範囲

出力・成果物の分量と作業範囲の規律は `docs/behavior-invariants.md` に単一出典化している。モデル名・モデル版を直書きせず、挙動として観測される不変条件の形で書く。成果物にどの節が存在するかは各出力形式テンプレートの責務であり、節の中身の分量が同文書の責務である。

スキル定義へ「自分が書いたものを自分で読み直せ」型の確認ステップを追加しない。この種の確認は指示がなくても行われるため、重ねて指示すると過剰な検証を誘発する。ただし別文脈が差分・要件を初見で読む独立検証（`code-reviewer` / `plan-reviewer` / `test-spec-validator`）、コマンドを実行して証拠を得る検証ゲート、完了判定における全項目の列挙（`completion-judgment.md`）は対象外であり、削減しない（ADR-202607261002-03）。

## 横断規約の出典

着手前に読む。本文を本ファイルへ転記しない。

- `docs/development/coding-agent-plugin-design-principles.md` — 配布プラグイン共通の8設計原則（工場と配布物の資産の別、工場固有の工程を利用者へ課さないこと、独立起動できる能力、成果物の4分類、契約項目、承認の帰属、host 依存方向、正本の一意性）と適用対象・非適用条件。新しいプラグインを起こすとき、既存プラグインへ能力を足すとき
- `docs/references/subagent-execution-parameters.md` — サブエージェントの `model` / `effort` の置き場と選択規則。新規サブエージェントは front-matter へ両方を明示する
- `docs/references/document-permanence.md` — `docs/` 配下へ何を残し何を残さないか（恒久文書／過去記録／区分対象外の区分基準）。`docs/principles.md`「ストック情報とフロー情報」の軸へ接続する

## DoR Framework

`create-issue`（作成時の前倒し充足）と `refine-issue`（作成後の精査）が共有する `dev-workflow` 配布物の内部設計である。転換期間中、本リポジトリ自身の開発工程では使わない（ADR-202609110017-01 決定5）。

定義の読み込み優先順位は `{project}/.claude/dor/definition.md`（プロジェクト固有）→ `${CLAUDE_PLUGIN_ROOT}/references/dor-default.md`（プラグイン共有の既定）。Issue サイズ（Small/Medium/Large）に応じてチェック項目が段階的に増える。二軸目として Issue 種別（bug/feature/refactor/spike/chore/docs）を持ち、`{project}/.claude/dor/type-profiles.md` → `${CLAUDE_PLUGIN_ROOT}/references/issue-type-profiles.md` の順で読む（ADR-202606180122-01）。種別ごとに追加必須セクション・AC 形／完了定義・適正な抽象度の厳しさを差別化し、サイズ判定を置換しない。

## Conventions

- ドキュメントおよびスキル内のコメントは日本語で書く
- スキルは GitHub CLI (`gh`) のみに依存し、プロジェクト固有のツールへ依存しない
- 複数行コンテンツは一時ファイルへ書き出し `--body-file` 等のファイル経由オプションで渡す（`allowed-tools` の Bash パターンがヒアドキュメント等の複雑なコマンドに一致しないため）
- スキルの出力形式（テーブル・レポート等）は各 SKILL.md 内に明示する

## Rules

- 計画や設計の議論中にユーザーが決定を下したら、即座に計画ドキュメントへ反映する。古い前提のまま進めない
- 設計議論を始める前に `docs/adr/` の ADR 一覧を確認する。設計判断を行ったら、却下代替の必要条件と粒度判定基準に照らして ADR 化要否を判定する（基準は `manage-adr` スキルが規定する。由来は ADR-202608011651-01 決定1）
- 転換期間中、本リポジトリでは `manage-adr` の遷移操作（承認・上書き・廃止・分割）を使わず、起票・発番と front-matter のスキーマ検査・識別子の一意性検査に縮める（ADR-202609110017-01 決定6）。既存 ADR と矛盾する判断を行う場合は、新規起票と旧 ADR の扱いをその場で決める
