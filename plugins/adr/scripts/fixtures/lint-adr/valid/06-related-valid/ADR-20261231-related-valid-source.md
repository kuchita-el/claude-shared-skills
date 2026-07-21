---
status: 承認済み
validity: 有効
---
# ADR-20261231-related-valid-source: 全書式の Related が有効先を指す source

## Status

承認済み

## Context

fixture 用（valid/06）。バレット有無×リンク有無の4書式の `Related:` がいずれも有効 ADR を先頭 stem に持つ。散文が退役 slug を引用しても先頭 stem が有効なら誤検出しないこと、`## 保留した決定`（パーク欄）が有効先・退役先(存在)のいずれを指しても違反にならないこと（J4＝park は dangling 検査のみ）を確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 は退役・dangling とも誤検出せず exit 0 を維持する。

## 保留した決定

- あるfacet を未決のまま残す（想定継承先: ADR-20261232-related-valid-target-a）
- 別facet を未決のまま残す（想定継承先: ADR-20261234-related-valid-retired-mentioned）（park は dangling 検査のみ＝退役でも違反にしない）

## 関連ADR

- Related: ADR-20261232-related-valid-target-a（バレット＋plain、有効先）
Related: ADR-20261233-related-valid-target-b（穴1 バレット無し＋plain、有効先）
- Related: [ADR-20261232-related-valid-target-a](./ADR-20261232-related-valid-target-a.md)（穴2 バレット＋リンク、有効先）
Related: [ADR-20261233-related-valid-target-b](./ADR-20261233-related-valid-target-b.md)（穴1＋穴2 バレット無し＋リンク、有効先）
- Related: ADR-20261233-related-valid-target-b（先頭stem＝有効。分割以前は上書き済みの ADR-20261234-related-valid-retired-mentioned を指していた＝散文の退役引用は先頭stemでないため誤検出しない）
