---
status: 承認済み
validity: 有効
---
# ADR-202612191035-01-layer-order-related-source: 出力順 fixture のレイヤ4 違反（参照元）

## Status

承認済み

## Context

fixture 用（invalid/35）。有効な ADR から、退役（上書き済み）の
ADR-202612151035-01-layer-order-forward-old を Related で参照する。レイヤ4 の参照先退役違反
1件だけを担う。参照先には後継が実在するため、後継なし退役先（違反にならない経路）とは
区別される。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が参照先退役違反を1件報告する。

## 関連ADR

- Related: ADR-202612151035-01-layer-order-forward-old
