---
description: ADR のライフサイクル操作（起票・承認・上書き・廃止・却下の5遷移）を実行し、front-matter（`status`/`validity`/`superseded-by`）と相互参照を ADR-20260711-3 のスキーマに従って書き込む。既存 ADR を編集する際は core／非core／些末の判定フローで変更種別を確定し、core 変更は新規 ADR 起票＋旧 ADR 上書きへ、非core／些末は直接編集へ導く。各操作後は lint-adr で自己検証する。ADR を新規に起こしたい・承認や上書き等で状態を変えたい・既存 ADR を編集したいときに使用。
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Bash(bash *scripts/lint-adr.sh*)
  - Bash(bash *scripts/gen-adr-index.sh*)
---

# ADRライフサイクル操作（Manage ADR）

ADR の各遷移（起票・承認・上書き・廃止・却下）と既存 ADR の編集で、front-matter（`status`/`validity`/`superseded-by`）と `## 関連ADR` の相互参照を正しく書き込む。README 手順を手作業で追わず、スキル経由で一貫した状態遷移を実行し、各操作の締めに drift-lint で自己検証する。

## 正本（唯一の出典）

`docs/adr/ADR-20260711-3-adr-two-axis-status-validity-model.md` が本スキルの正本。以下を常にそこから読み込み、スキル独自の状態語彙・判定基準を導入しない。

- **決定2**: front-matter スキーマの必須ルール表（承認軸 `status` × 有効性軸 `validity`）
- **決定3**: 編集判定フロー（core／非core／些末）と安全則「迷ったら core」・ADR分割
- **決定6**: ライフサイクル操作の tooling 委譲方針
- **決定8**: 採番方式 `ADR-YYYYMMDD[-N]`・配置（`docs/adr/` フラット）

状態値は日本語ユビキタス言語（`提案中`/`承認済み`/`却下`/`有効`/`上書き済み`/`廃止済み`）、キーは英語。値の説明・トレーリングコメントを front-matter 内に書かない（lint パーサが行全体を値として取り込むため）。

## 引数

- 操作種別（`起票`／`承認`／`上書き`／`廃止`／`却下`／`編集`）と対象 ADR の識別子・パス
- 省略時は会話コンテキストから意図を判定する。操作種別・対象が特定できなければ、その1点のみ質問する

## 対象操作

### 5遷移（front-matter 状態遷移）

| 操作 | 概要 |
|---|---|
| 起票 | 採番規則で新規 ADR ファイルを生成し `status: 提案中`（`validity`/`superseded-by` は空） |
| 承認 | `status: 承認済み`・`validity: 有効`（`superseded-by` は空のまま） |
| 上書き | 旧 ADR に `validity: 上書き済み`・`superseded-by: <後継>`、後継本文 `## 関連ADR` に `Supersedes: <旧>`（双方向） |
| 廃止 | `validity: 廃止済み`（`superseded-by` は付与しない） |
| 却下 | `status: 却下`（`validity`・`superseded-by` は付与しない） |

各遷移後の front-matter 最終状態は正本・決定2の表に一致させる。採番規則・写入手順・上書きの双方向相互参照の書き込みは `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照する。

### 編集判定フロー（既存 ADR の変更）

`validity: 有効` な ADR への変更は、変更種別（core／非core／些末）を `AskUserQuestion` で利用者へ問って確定する。既定選択肢は core（安全則「迷ったら core」）。分類に応じて操作を分岐する。

- **core** → 新規 ADR 起票＋旧 ADR 上書き（5遷移へ）
- **非core** → 直接編集＋本文 `## 変更履歴` に1行追記（front-matter は不変）
- **些末** → 直接編集のみ（front-matter・`## 変更履歴` 不変、履歴は git）

分類はスキルが自動判定せず、必ず利用者へ問う。判定基準・問い設計・分岐の詳細は `${CLAUDE_SKILL_DIR}/references/edit-decision.md` を参照する。`上書き済み`／`廃止済み` に退役した ADR は凍結された歴史的成果物であり本文編集しない。

## 手順の参照（各 references を直接参照）

- `${CLAUDE_SKILL_DIR}/references/transitions.md` — 5遷移の front-matter 写入・採番規則・双方向相互参照の手順
- `${CLAUDE_SKILL_DIR}/references/edit-decision.md` — core／非core／些末 の判定と `AskUserQuestion` 問い設計・操作分岐
- `${CLAUDE_SKILL_DIR}/references/io-examples.md` — 起票・承認・上書きの入出力例

採番日（起票日）は外部コマンド（`date`）を実行せず、実行時コンテキストの現在日付から取得する。

## 各操作後の自己検証（必須・隔離コピー検証）

実 ADR ファイルは `docs/adr` に書き込むが、**自己検証は live `docs/adr` を直接 lint しない**。現状の `docs/adr` 全体は `index.md` 未生成・未移行 ADR の drift により baseline が exit 1（red）であり、#③（既存 ADR の front-matter 移行・index 初期生成）完了までは、どれだけ正しく操作しても全体 green にできない。live を直接 lint して「exit 0 まで反復」すると正しい操作でも永久に完了しないため、**変更/生成した ADR を隔離コピーしたディレクトリ**に対して検証する。

各遷移・編集操作の完了後、以下を実行する。

0. **隔離コピー作成**: 一時ディレクトリ（作業用 scratchpad 等）を作り、**本操作で変更/生成した ADR ＋その相互参照相手を漏れなくコピーする**。コピーセットの規則は `${CLAUDE_SKILL_DIR}/references/transitions.md`（「自己検証の隔離コピーセット」節）を参照する。とりわけ上書きは**旧 ADR ＋後継 ADR の2ファイルを必ず含める**（旧単体だと後継不在でレイヤ3 forward が発火し false negative になる）。
1. **index 同期**（`validity` を変える操作＝承認・上書き・廃止の後）: `bash scripts/gen-adr-index.sh <隔離ディレクトリ>` の出力で `<隔離ディレクトリ>/index.md` を再生成する（起票・却下は `validity` を変えないため index 再生成不要）。
2. **lint 実行**: `bash scripts/lint-adr.sh <隔離ディレクトリ>` を実行し exit 0 を確認する。**この exit 0（＝隔離セットに新たなスキーマ違反・相互参照違反が無いこと）が合否基準**である。
3. **フィードバックループ**（exit 0 以外）: lint-adr の出力（レイヤ1 スキーマ／レイヤ2 index 同期 drift／レイヤ3 相互参照）を利用者へ提示し、指摘に応じて実 ADR（`docs/adr` 側）を修正する — front-matter（`status`/`validity`/`superseded-by`）または相互参照（旧側 `superseded-by`・後継側 `Supersedes:`）を直す。修正を隔離コピーへ反映し、レイヤ2 drift なら `gen-adr-index.sh` を再実行して index を同期する。再度 lint-adr を実行し、**隔離セットが exit 0 になるまで反復する**。exit 0 を得られないまま操作を完了扱いにしない。

`lint-adr.sh` の exit code: `0`＝違反0件／`1`＝違反検出／`2`＝対象ディレクトリ不在。隔離ディレクトリは使い捨てで、成果物は `docs/adr` 側の実 ADR ファイルである。

本自己検証は #①成果物（`scripts/lint-adr.sh`／`scripts/gen-adr-index.sh`）に依存する。`docs/adr` 本体での全体 green 化は #③（front-matter 移行・index 初期生成）完了後に持ち越す。#③ 完了後は `docs/adr` を直接検証する方式へ簡素化しうる（本節の隔離コピーは #③ 未完了の過渡措置）。
