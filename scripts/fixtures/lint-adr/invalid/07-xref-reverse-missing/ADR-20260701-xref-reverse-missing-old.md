---
status: 承認済み
validity: 有効
---
# ADR-20260701-xref-reverse-missing-old: 相互参照逆方向欠落の旧決定

## Status

承認済み

## Context

fixture 用。後継 ADR-20260702-xref-reverse-missing-new の本文が
`Supersedes: ADR-20260701-xref-reverse-missing-old` を宣言しているが、
本ADR側の front-matter 更新（validity: 上書き済み・superseded-by 付与）が
忘れられている corpus（逆方向の相互参照違反を検出させる）。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

front-matter 更新忘れにより validity: 有効 のまま index に残り続ける
（これがレイヤ3逆方向検証で検出すべきドリフト）。
