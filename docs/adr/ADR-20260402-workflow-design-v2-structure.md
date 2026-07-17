---
status: 承認済み
validity: 有効
---

# ADR-20260402: workflow-design.md v2 構造選定（Discovery追加・用語フレームワーク非依存化・フロー/ストック軸分離）

## Context

`docs/workflow-design.md` v1（初版）は Delivery フェーズ中心、Epic/feature 等の SAFe/Scrum/Jira 依存用語を採用し、ドキュメント配置を「フェーズで分類（`docs/discovery/`・`docs/delivery/`）」していた。AIエージェントを Discovery にも投入する方針、Discovery 成果物を Delivery で参照するドキュメンテーション戦略の必要性、用語のフレームワーク横断性確保の必要性が浮上し、v2 として全面改訂する判定が必要となった。

関連: PR #89（`docs: workflow-design.mdをDiscovery/Delivery構成に全面改訂`、MERGED 2026-04-02）。用語改訂は 2026-04-02 にフォローアップ実施。

## Decision

`docs/workflow-design.md` の構造として以下を採用する。

1. **Discovery フェーズの守備範囲化**: workflow-design.md は Delivery のみではなく Discovery も対象。Discovery でも AI エージェントの力を借りる前提、および Discovery 成果物の Delivery 参照のためのドキュメンテーション戦略を含める
2. **用語のフレームワーク非依存化**: Epic/feature 等のフレームワーク特化用語を排し、以下に統一する
    - フロー（作業管理）の階層: 「テーマ」「デリバリーアイテム」「タスク」（プロジェクト管理の原理）
    - ストック（ドキュメント）の階層: 「ドメイン」「ユースケース」「spec.md」（ソフトウェアアーキテクチャの原理）
    - 整理の原理が異なるため、フローとストックは別の軸として扱う
3. **フロー軸とストック軸の接続**: デリバリーアイテム（Issue）が、どのユースケースの spec.md を参照するか、で接続される。1対1ではなく多対多関係を許容
4. **ドキュメント配置原則「フェーズではなくドメインで分類」**: `docs/discovery/` は不要。Discovery/Delivery は時間軸であって空間軸（ドメイン分類）に反映しない。ドメインで分類した配下にユースケースを置く
5. **ユースケースレベルのストック情報の集約**: `docs/{domain}/use-cases/{name}/spec.md` にドメインマッピング（どの集約・状態遷移・コマンドを担うか）、受け入れ基準、外部リソースリンク（Figma等）を集約。Issue の AC は作業駆動用（フロー）、spec.md がストック
6. **廃止事項**:
    - `requirements-writer` スキルの構想を廃止（spec.md + Issue の AC で代替）
    - `docs/discovery/user-stories.md` 廃止（spec.md に統合）
    - workflow-design.md からテンプレート・CI 設定例を外部化（ストック責務外）

## Consequences

**得られた利益**:

- フロー（Issue/タスク管理）とストック（spec.md/ドメインモデル）が別軸として整理され、双方を独立進化させられる
- フレームワーク非依存用語により SAFe/Scrum/Kanban いずれのチームでも参照可能な設計書になる
- ドメイン分類採用により Discovery 成果物が Delivery でも自然に参照される（時間軸が空間軸を侵食しない）

**受容したトレードオフ**:

- v1 を読み慣れたメンバーには用語移行コストが発生
- 「テーマ・デリバリーアイテム・タスク」は具体的ツール（Linear/GitHub Issues 等）との直接マッピングを持たず、運用時に翻訳が必要
- spec.md 配置・命名規約（`docs/{domain}/use-cases/{name}/spec.md`）の固定化により、ドメイン階層の構造変更時の追従コストが残る

**将来の留保事項**:

- spec.md のライフサイクル管理（Issue #95 OPEN）、Delivery→Discovery のフィードバックループ詳細（Issue #94 CLOSED で初期定義）は別Issueで継続検討
- 採番方式 `docs/adr/{番号}-{タイトル}.md` の旧記述（v1 名残）は ADR-20260511 で `ADR-YYYYMMDD[-N]` に上書き済。workflow-design.md 本文の整合は別途必要

## 関連ADR

Amended by: ADR-20260602-principles-rationale-hub（責務定義 facet を改訂。本ADRは Accepted 維持・残り5決定は有効。初版 amend は ADR-20260531-2 だが同 ADR は ADR-20260602 に Superseded されたため、現行の amend 元は ADR-20260602）

Related: ADR-20260511-technical-decision-aggregate-foundation（ADR採番方式は本ADRの旧記述を上書き）

関連Issue: PR #89（workflow-design.md v2 改訂本体）、#94（Delivery→Discovery フィードバックループ）、#95（spec.md ライフサイクル）、#100（AIエラー時の再開・引き継ぎ）

由来memory: `project_workflow_design_v2.md`（本ADR起票によりmemory削除済、個人スコープ要素なしのため全削除）
