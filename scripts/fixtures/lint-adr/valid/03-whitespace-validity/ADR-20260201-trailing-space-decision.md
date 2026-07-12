---
status: 承認済み
validity: 有効 
---
# ADR-20260201-trailing-space-decision: 末尾空白検証用決定

## Status

承認済み

## Context

fixture 用。front-matter の validity 値に末尾空白（半角スペース1個）を持つ ADR。
gen-adr-index.sh がトリムせずに「有効」と完全一致比較すると index から静かに除外されるドリフトの回帰検証用。

## Decision

採用する。

## Consequences

fixture として gen-adr-index.sh / lint-adr.sh の入力に使う。
