---
status: 承認済み
validity: 有効
---
# ADR-20261220-01-layer-order-legacy-name: 出力順 fixture のレイヤ5 違反

## Status

承認済み

## Context

fixture 用（invalid/35）。ファイル名の時刻部が旧規約の8桁であり、
`ADR-YYYYMMDDHHMM-NN-<slug>.md` の形式に適合しない。レイヤ5 のファイル名形式違反1件だけを
担う。識別子部（ADR-20261220-01）は本 ADR 群で一意であり、H1 見出しと一致するため、
識別子重複・H1 整合の分岐は発火しない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ5 がファイル名形式違反を1件報告する。

## 関連ADR

なし。
