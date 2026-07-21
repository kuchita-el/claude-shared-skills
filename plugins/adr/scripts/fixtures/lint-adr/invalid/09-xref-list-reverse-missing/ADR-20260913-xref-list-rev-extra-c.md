---
status: 承認済み
validity: 有効
---
# ADR-20260913-xref-list-rev-extra-c: reverse検証用の非列挙後継C（違反側）

## Status

承認済み

## Context

fixture 用。09 の第三の後継C。本文で old を Supersedes 宣言するが、old の
superseded-by リスト（A, B のみ）には列挙されていない。C 追加時のリスト更新忘れを模す。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

このエッジのみ reverse 相互参照違反として検出されることを検証する。

## 関連ADR

- Supersedes: ADR-20260910-xref-list-rev-old
