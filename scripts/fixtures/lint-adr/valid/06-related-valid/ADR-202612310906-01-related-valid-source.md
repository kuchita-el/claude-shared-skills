---
status: 承認済み
validity: 有効
---
# ADR-202612310906-01-related-valid-source: 全書式の Related が有効先を指す source

## Status

承認済み

## Context

fixture 用（valid/06）。バレット有無×リンク有無の4書式の `Related:` がいずれも有効 ADR を先頭 stem に持つ。散文が実在しない slug を引用しても先頭 stem が有効なら誤検出しないことを確認する。加えて、先頭 stem が後継を持たずに退役した（`廃止済み`）ADR である `Related:` 行を1本持つ。差し替え先が存在せず建設的な是正が無いため、この参照は退役検査の対象外であり違反にならないことを確認する。

散文のデコイに**実在しない** stem を使うのは、後続 stem を拾ってしまう退行が違反として現れることでこの行の回帰が成り立っているためである。デコイに退役 ADR を使うと、退役検査が対象とする `validity` 値の増減で違反になるかどうかが変わり、語彙が縮んだ時点で退行が素通りする。dangling 検査は参照先の `validity` に依存しないため、語彙の増減に影響されない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 は退役・dangling とも誤検出せず exit 0 を維持する。

## 関連ADR

- Related: ADR-202701010906-01-related-valid-target-a（バレット＋plain、有効先）
Related: ADR-202701020906-01-related-valid-target-b（穴1 バレット無し＋plain、有効先）
- Related: [ADR-202701010906-01-related-valid-target-a](./ADR-202701010906-01-related-valid-target-a.md)（穴2 バレット＋リンク、有効先）
Related: [ADR-202701020906-01-related-valid-target-b](./ADR-202701020906-01-related-valid-target-b.md)（穴1＋穴2 バレット無し＋リンク、有効先）
- Related: ADR-202701020906-01-related-valid-target-b（先頭stem＝有効。散文が実在しない ADR-209901010101-01-nonexistent-quoted を引用しても先頭stemでないため拾わない。後続stemを拾う退行が入るとdangling違反として現れる）
- Related: ADR-202701030906-01-related-valid-retired-mentioned（先頭stem＝後継を持たずに退役した廃止済み ADR。差し替え先が存在しないため退役検査の対象外であり違反にならない）
