---
status: 承認済み
validity: 有効
---
# ADR-202612171035-01-layer-order-reverse-claimant: 出力順 fixture のレイヤ3 reverse 違反（宣言側）

## Status

承認済み

## Context

fixture 用（invalid/35）。本文で上書きを宣言するが、参照先
ADR-202612181035-01-layer-order-reverse-target の front-matter superseded-by が本 ADR を
指していない（front-matter 更新忘れ）。レイヤ3 reverse の1件だけを担う。参照先は実在する
ため、参照先そのものが不在の分岐（invalid/34）とは別の経路になる。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ3 reverse が front-matter の追随欠落を1件報告する。

## 関連ADR

- Supersedes: ADR-202612181035-01-layer-order-reverse-target
