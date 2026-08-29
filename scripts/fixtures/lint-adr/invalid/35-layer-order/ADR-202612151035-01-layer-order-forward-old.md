---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-202612161035-01-layer-order-forward-new
---
# ADR-202612151035-01-layer-order-forward-old: 出力順 fixture のレイヤ3 forward 違反（旧決定）

## Status

承認済み（上書き済み）

## Context

fixture 用（invalid/35）。front-matter に superseded-by を持つが、後継
ADR-202612161035-01-layer-order-forward-new の本文が逆参照を宣言していない。レイヤ3 forward
の1件だけを担う。あわせて、退役（上書き済み）ADR としてレイヤ4 の参照先にもなる。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ3 forward が本文の逆参照欠落を1件報告する。index には現れない（有効でないため）。

## 関連ADR

- Superseded by: ADR-202612161035-01-layer-order-forward-new
