---
status: 承認済み
validity: 有効
---
# ADR-20260203-xref-amends-example: 相互参照検証用のAmends凍結例

## Status

承認済み

## Context

fixture 用。`superseded-by` を持たず、本文に `Amends:` のみを持つ ADR。
レイヤ3が `Amends:`/`Amended by:` を検査対象外とし、片側欠落でも
違反にしないことを確認する凍結例。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

fixture として index 生成器の入力に使う。

## 関連ADR

- Amends: ADR-20250101-legacy-baseline-decision（facet。参照先は fixture 上に存在しないが、Amends は検査対象外のため違反にならない）
