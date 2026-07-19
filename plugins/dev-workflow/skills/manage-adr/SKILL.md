---
description: ADR のライフサイクル操作（起票・承認・上書き・廃止・却下の5遷移）を実行し、front-matter（`status`/`validity`/`superseded-by`）と相互参照をスキーマに従って書き込む。既存 ADR を編集する際は core／非core／些末の判定フローで変更種別を確定し、core 変更は新規 ADR 起票＋旧 ADR 上書きへ、非core／些末は直接編集へ導く。ADR 化要否も判定する。各操作後は lint-adr で自己検証する。ADR 化すべきか迷う・ADR を新規に起こしたい・承認や上書き等で状態を変えたい・既存 ADR を編集したいときに使用。
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

各遷移後の front-matter 最終状態は `${CLAUDE_SKILL_DIR}/references/adr-model.md` の必須ルール表に一致させる。採番規則・写入手順・上書きの双方向相互参照の書き込みは `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照する。

### 編集判定フロー（既存 ADR の変更）

`validity: 有効` な ADR への変更は、変更種別（core／非core／些末）を `AskUserQuestion` で利用者へ問って確定する。既定選択肢は core（安全則「迷ったら core」）。分類に応じて操作を分岐する。

- **core** → 新規 ADR 起票＋旧 ADR 上書き（5遷移へ）
- **非core** → 直接編集＋本文 `## 変更履歴` に1行追記（front-matter は不変）
- **些末** → 直接編集のみ（front-matter・`## 変更履歴` 不変、履歴は git）

分類はスキルが自動判定せず、必ず利用者へ問う。判定基準・問い設計・分岐の詳細は `${CLAUDE_SKILL_DIR}/references/edit-decision.md` を参照する。`上書き済み`／`廃止済み` に退役した ADR は凍結された歴史的成果物であり本文編集しない。

### ADR 化要否の判定（起票の前段）

ある決定を ADR にすべきか、いつ起票するか、命名規約を ADR の対象に含めるかは、粒度判定基準（4項目チェックリストとスコア境界）で判定する。判定境界では「書かない」を優先する。判定項目・スコア境界・昇格のタイミング・命名規約の振り分けは `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` を参照し、スキル独自の基準を導入しない。

要否の判定は起票操作の前段であり、ADR 化すると判断した場合のみ起票（5遷移）へ進む。

## 手順の参照（各 references を直接参照）

- `${CLAUDE_SKILL_DIR}/references/adr-model.md` — 状態の2軸の値域・遷移ごとの front-matter 必須ルール表・配置・採番方式（full slug の定義）
- `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` — ADR 化要否の粒度判定基準・起票のタイミング・命名規約の ADR 化基準
- `${CLAUDE_SKILL_DIR}/references/template.md` — 新規 ADR の雛形（front-matter＋見出し骨格。起票時にこの構成へ準拠する）
- `${CLAUDE_SKILL_DIR}/references/transitions.md` — 5遷移と分割の実行手順・採番規則・双方向相互参照の書き込み・index の再生成
- `${CLAUDE_SKILL_DIR}/references/edit-decision.md` — core／非core／些末 の判定と `AskUserQuestion` 問い設計・操作分岐
- `${CLAUDE_SKILL_DIR}/references/io-examples.md` — 起票・承認・上書きの入出力例

採番日（起票日）は外部コマンド（`date`）を実行せず、実行時コンテキストの現在日付から取得する。

## 各操作後の自己検証（必須）

実 ADR ファイルは `docs/adr` に書き込み、**自己検証も `docs/adr` を直接対象として実行する**。各遷移・編集操作の完了後、以下を実行する。

1. **index 同期**（`validity` を変える操作＝承認・上書き・分割・廃止の後）: `bash scripts/gen-adr-index.sh docs/adr` の出力で `docs/adr/index.md` を再生成する（起票・却下は `validity` を変えないため index 再生成不要）。
2. **lint 実行**: `bash scripts/lint-adr.sh docs/adr` を実行し exit 0 を確認する。**この exit 0 が合否基準**である。
3. **フィードバックループ**（exit 0 以外）: lint-adr の出力（レイヤ1 スキーマ／レイヤ2 index 同期 drift／レイヤ3 相互参照）を利用者へ提示し、指摘に応じて ADR を修正する — front-matter（`status`/`validity`/`superseded-by`）または相互参照（旧側 `superseded-by`・後継側 `Supersedes:`）を直す。レイヤ2 drift なら `gen-adr-index.sh` を再実行して index を同期する。再度 lint-adr を実行し、**exit 0 になるまで反復する**。exit 0 を得られないまま操作を完了扱いにしない。

`lint-adr.sh` の exit code: `0`＝違反0件／`1`＝違反検出／`2`＝対象ディレクトリ不在。

**フォールバック**: 操作前から `docs/adr` が exit 1（baseline red）で、本操作と無関係な違反が exit 0 到達を妨げる場合に限り、変更/生成した ADR とその相互参照相手を一時ディレクトリへコピーし、そのディレクトリを対象に手順1〜3を実行してよい（コピーに含めるファイルの規則は `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照）。

**方式の判断と根拠**: 既定を `docs/adr` 直接検証とし、隔離コピー方式は既定手順から退けた。隔離コピーは「対象ディレクトリ全体の baseline が red で、どれだけ正しく操作しても全体 green にできない」ことを前提とする過渡措置であり、直接 lint すると正しい操作でも exit 0 に到達できない（false negative）ことを避けるためのものだった。front-matter 移行と index 初期生成の完了により baseline が exit 0 となってこの前提が失効したため、隔離方式には相互参照相手を漏らすと自ら false negative を生むという組み立てコストだけが残る。直接検証は操作結果と `docs/adr` 全体の整合を同時に検査でき、隔離セットの漏れによる誤検知も生じない。ただし baseline が red へ戻った場合の可用性を確保するため、隔離検証は上記フォールバックとして残置する。
