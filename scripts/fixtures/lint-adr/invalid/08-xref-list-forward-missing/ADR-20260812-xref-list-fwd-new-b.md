---
status: 承認済み
validity: 有効
---
# ADR-20260812-xref-list-fwd-new-b: forward検証用の後継B（逆参照欠落・違反側）

## Status

承認済み

## Context

fixture 用。08 の後継B。本文 `## 関連ADR` に Supersedes 逆参照を書き忘れた（欠落）側。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

このエッジのみ forward 相互参照違反として検出されることを検証する。

## 関連ADR

- 上書き元: ADR-20260810-xref-list-fwd-old（Supersedes 行を意図的に欠く）
