---
validity: 有効
---
# ADR-202612141035-01-layer-order-status-missing: 出力順 fixture のレイヤ1 違反

## Status

（front-matter に status キーが存在しない状態を再現する fixture）

## Context

fixture 用（invalid/35）。本 ADR 群は6つの検査単位を1本ずつ同時に発火させ、違反の
出力順が起動部の呼び出し順で決まることを観測させる。本ファイルはそのうちレイヤ1
（front-matter スキーマ）の1件だけを担う。ファイル名形式・H1 整合・相互参照・Related は
いずれも適合させ、他の単位を発火させない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ1 が `status が空です` を1件報告する。

## 関連ADR

なし。
