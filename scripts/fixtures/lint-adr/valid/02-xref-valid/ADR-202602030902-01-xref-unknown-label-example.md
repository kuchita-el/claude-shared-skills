---
status: 承認済み
validity: 有効
---
# ADR-202602030902-01-xref-unknown-label-example: 相互参照検証用の未知ラベル例

## Status

承認済み

## Context

fixture 用。`superseded-by` を持たず、本文 `## 関連ADR` に生存語彙
（`Supersedes:` / `Superseded by:` / `Related:`）以外のラベルのみを持つ ADR。
レイヤ3 の本文走査が `Supersedes:` のみを、レイヤ4 の抽出が `Related:` 行のみを
対象とするため、未知ラベルの行は参照先が実在しなくても違反にならないことを
確認する fail-open の例。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

fixture として index 生成器の入力に使う。

## 関連ADR

- Refines: ADR-202501010902-01-legacy-baseline-decision（未知ラベル。参照先は fixture 上に存在しないが、生存語彙でないため抽出されず違反にならない）
