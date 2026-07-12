---
status: 承認済み
validity: 有効
---
# ADR-20260402-drift-second-decision: drift検証用2件目の決定

## Status

承認済み

## Context

fixture 用の drift 検証 ADR（2件目）。同梱 index.md には意図的にこの ADR を含めず、
生成器の再生成結果との差分（同期違反）を発生させる。

## Decision

drift検証用2件目の決定を採用する。

## Consequences

fixture として index 同期違反（レイヤ2）検証の入力に使う。
