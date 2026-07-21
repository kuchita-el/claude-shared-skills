---
status: 承認済み
validity: 上書き済み
---
# ADR-20260602-multi-violation-superseded-by-missing: 複数違反fixture・後継欠落側

## Status

承認済み（上書き済み）

## Context

fixture 用。複数 ADR 同時違反の回帰テスト用 corpus（06-multi-violation）の2件目。
`validity: 上書き済み` だが front-matter が `superseded-by` キーを持たない。
レイヤ1違反3（validity=上書き済み かつ superseded-by 欠落）を検出させる。

## Decision

fixture 用のため実質的な決定内容は無い。
