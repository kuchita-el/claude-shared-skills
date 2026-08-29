---
status: 承認済み
validity: 有効
---
# ADR-202612181035-01-layer-order-reverse-target: 出力順 fixture のレイヤ3 reverse 違反（参照先）

## Status

承認済み

## Context

fixture 用（invalid/35）。ADR-202612171035-01-layer-order-reverse-claimant の本文から上書きを
宣言されているが、front-matter が追随していない（superseded-by を持たず validity も有効の
まま）。レイヤ3 reverse の違反はこのファイルを主語として報告される。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

front-matter を追随させるとレイヤ3 reverse の1件が消え、出力順の観測点が5つへ減る。

## 関連ADR

なし。
