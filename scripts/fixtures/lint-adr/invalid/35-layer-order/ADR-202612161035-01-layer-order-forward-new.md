---
status: 承認済み
validity: 有効
---
# ADR-202612161035-01-layer-order-forward-new: 出力順 fixture のレイヤ3 forward 違反（後継）

## Status

承認済み

## Context

fixture 用（invalid/35）。ADR-202612151035-01-layer-order-forward-old から superseded-by で
指されているが、本文が逆参照を宣言していない。宣言を足すとレイヤ3 forward の1件が消え、
出力順の観測点が5つへ減る。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ3 forward の違反は旧決定の側に報告される（本ファイルは参照先として名指しされる）。

## 関連ADR

なし。
