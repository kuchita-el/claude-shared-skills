# ADR-20260513: workflow-design.md にチーム規模別フローを含めない

## Status

Accepted

## Context

`docs/workflow-design.md` がチーム規模・チーム構成（例: 1人開発 / 小規模チーム / 大規模チーム）への対応を含むべきかが議論となった。記述を含めると AI と人間の協働における作業フロー設計に「人間チーム間の合意形成プロセス」が混在し、設計書の焦点がぼやけるリスクが識別された。

由来Issue/PR の特定が困難（memory `feedback_workflow_scope_team.md` の mtime 2026-04-04 から議論時期は推定可能だが、紐づく Issue/PR は不明）。本 ADR は計画書「選択肢B」の fallback ルールに従い、本Issue（#170）着手日 2026-05-13 で採番する。

## Decision

`docs/workflow-design.md` のスコープから、チーム規模・チーム構成への対応を除外する。

1. **対象外項目**: チーム規模・チーム構成に依存するフロー差異（合意形成プロセスのバリエーション、レビュアー人数の規模別ガイドライン等）
2. **理由**:
    - チーム規模による差異は「人間による判断に複雑なフローがあるか」の差でしかない
    - workflow-design.md の責務は「AIと人間の協働における作業フローと品質ゲート」であり、人間チーム内の合意形成プロセスは別の関心事
    - 設計書に織り込むと焦点がぼやけ、AIエージェント設計の意思決定根拠としての利用しづらさを招く
3. **運用上の取り扱い**:
    - workflow-design.md のスコープセクションで本除外を免責する
    - workflow-design.md に対してチーム規模・合意形成プロセスの不足を指摘しない（レビュー時の運用ルール）
    - チーム規模別フローが必要な場合は別ドキュメント（例: `workflow-patterns.md`、Issue #118 OPEN）に切り出す

## Consequences

**得られた利益**:

- workflow-design.md の焦点が「AI/人間協働の作業フロー＋品質ゲート」に絞り込まれ、AIエージェント設計の意思決定根拠として利用しやすくなる
- 設計書のメンテナンスコストが低減（チーム規模別の場合分けが不要）

**受容したトレードオフ**:

- チーム規模別の運用ガイドを workflow-design.md からは得られないため、別ドキュメント（Issue #118）への分離管理が必要
- 「チーム規模対応がない」という指摘がレビューで繰り返し発生する可能性がある（スコープセクションでの免責で対応）

**将来の留保事項**:

- パターン別ワークフロー定義（`workflow-patterns.md`、Issue #118 OPEN）でチーム規模別の運用を別途扱う

## 関連ADR

Related: ADR-20260402-workflow-design-v2-structure（workflow-design.md v2 構造選定。本ADRは v2 のスコープを限定する補足判定）

関連Issue: #118（プラグイン共通: パターン別ワークフロー定義 `workflow-patterns.md` の設計・作成、OPEN）

由来memory: `feedback_workflow_scope_team.md`（本ADR起票によりmemory削除済、個人スコープ要素なしのため全削除）
