# ADR-20260511: 技術的意思決定集約の運用基盤（採番方式・配置・ライフサイクル・廃止扱い）

## Status

Accepted

## Context

ホットスポット H4「ADR（Architecture Decision Records）のライフサイクル管理が未定義。横断的技術方針の蓄積・参照・廃止の仕組みがない」由来の決定。Issue #130 で技術的意思決定を独立集約として正式モデル化し（旧「横断的技術方針」を改名）、状態遷移・コマンド・イベントを確定した。しかし集約の実体（ADR ファイル）を運用するための採番方式・配置場所・ライフサイクル状態名・後継参照の扱いが Issue #130 と Issue #169 にまたがって決定されており、ADR として一括参照可能な単一の根拠ドキュメントが存在しない状態だった。

本 ADR は Issue #130 で確定した4項目（採番方式・配置・ライフサイクル状態・廃止時の扱い）を ADR 形式で正式化し、`docs/development/event-storming.md`「技術的意思決定」集約および `docs/adr/README.md` 運用ルールの根拠として位置付ける。

関連ホットスポット: H4（Issue #130 で部分解消、運用基盤は Issue #169 で確定）

## Decision

技術的意思決定集約の運用基盤として以下を採用する。

1. **採番方式**: `ADR-YYYYMMDD[-N]`
    - 同日1件目は `-N` なし、2件目以降は `-2` から付与
    - 採番衝突時は対象日のADRファイル一覧から最大番号+1で発番
    - 採番日＝ADR起票日とする運用
2. **配置**: `docs/adr/` 配下にフラット構造で配置する。サブディレクトリは作らない
3. **ライフサイクル状態（4状態）**: Proposed / Accepted / Deprecated / Superseded
    - Proposed → Accepted（必須起点） / Accepted → Deprecated / Accepted → Superseded の3遷移
    - 状態名は ADR 業界慣例（Nygard ADR / MADR）に倣い英文表記で確定（他集約の和文表記とは意図的に揃えない）
4. **廃止時の扱い**: 後継ありは Superseded（後継ADR識別子を文字列参照として保持）、後継なしは Deprecated（後継参照を持たない）
    - 後継ADR識別子は文字列のみ。集約インスタンスへの直接参照は持たず、自己参照・循環参照の構造的不整合を防ぐ

## Consequences

**得られた利益**:

- 集約モデル（`docs/development/event-storming.md`・`docs/development/domain-model.md`「技術的意思決定」集約）とファイル運用（`docs/adr/`）の表記が一致する
- 検索性は採番（日付）＋slug（内容）で担保される。日付からは時系列、slug からは内容軸でナビゲート可能
- Phase 1（Issue #170）以降で既存 memory 判定の遡及 ADR 化に着手可能となる

**受容したトレードオフ**:

- ライフサイクル状態名のみ英文表記（他集約は和文）。`docs/development/event-storming.md:478` の設計判断「技術的意思決定集約の状態名を英文表記とする」と整合。代替案（和文統一・併記）は ADR ファイル Status 欄との二重管理や記述冗長化のため却下
- 採番方式 `ADR-YYYYMMDD[-N]` は `docs/workflow-design.md:166-186` の旧採番方式（`docs/adr/{番号}-{タイトル}.md`）と矛盾するが、本 ADR を正とし、`workflow-design.md` の旧記述整合は Issue #170 以降の Phase 1 整合作業に委譲する

**将来の留保事項**:

- フレームワーク利用側（他プロジェクト）への展開（テンプレ抽出・セットアップスキル等）は dogfooding 範囲の運用観測を踏まえて別途検討する
- ADR 捕捉プロセス（Issueクローズ時判定・PRテンプレ拡張・記録スキル）は Phase 2（Issue #171）で検討する

## 関連ADR

該当なし（本リポジトリにおける最初の ADR）

関連Issue: #130（技術的意思決定集約モデル化、CLOSED）、#169（ADR運用基盤整備、本 ADR の起票元）
